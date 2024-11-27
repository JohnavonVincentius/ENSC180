clear all;

% =================== SERVER CONFIGURATION ================== %
global playerGameStart;
SERVER_ADDR = "0.0.0.0";
SERVER_PORT = 5050;
playerGameStart = 2;

% ================== SERVER INITIALIZATION ================== %
disp('Initializing Game States...');
global players;
global playerHands;
global mainDeck;
global discardPile;
global currentTurn;
global client;
global app;

function connectionHandler(server, ~)
    % Check for new connections
    if server.Connected
        % Display client information
        disp('New client connected.');

        % Handle the client in a separate task
        clientTask = parfeval(@handleClient, 0, server);
        
        % Note: You can keep track of `clientTask` if needed for later management.
    else
        disp('A client disconnected.');
    end
end


client = tcpserver('127.0.0.1', 55000, 'ConnectionChangedFcn', @connectionHandler);
app = uifigure('Name', 'Uno Game Server Console', 'Position', [100, 100, 600, 400]);
uibutton(app, 'Text', 'Terminate Server', ...
    'Position', [450, 20, 120, 40], ...
    'ButtonPushedFcn', @(btn, event) terminateServer());

uibutton(app, 'Text', 'Broadcast State', ...
'Position', [10, 20, 100, 50], ...
'ButtonPushedFcn', @(btn, event) broadcastGameState());


players = [];
playerHands = [];
mainDeck = createUnoDeck();
discardPile = [];
currentTurn = 1;

disp('UNO Server started. Waiting for players to connect...');

function handleClient(server)
    % Read and respond to the client
    while server.Connected
        if server.Connected
            % Read incoming data
            if client.NumBytesAvailable > 0
                onSRVReceive(server);
            end
        end
        pause(0.1);
    end

    disp('Client handling completed.');
end


% ================== PRIMARY MAIN FUNCTION ================== %
global stop;
while true
    try 
        main();
    catch exception 
        disp("Error: " + exception.message);
    end 
    pause(0.1); % Prevent busy waiting
    if stop == true
        break
    end
end

% ======================= SERVER FUNCTIONS ======================= %

% ========== SERVER MAIN ========== %
% The main fuction that will run in a loop.
function main()
    global client;
    if client.Connected
        % Read incoming data
        if client.NumBytesAvailable > 0
            onSRVReceive(client);
        end
    end
end

% ========== PROCESS CLIENT REQUEST ========== %
function onSRVReceive(client)
    global players;
    jsonData = read(client, client.NumBytesAvailable, "string");
    data = jsondecode(jsonData);
    if isfield(data, 'type')
        switch data.type
            case 'connect'
                onPlayerConnect(client);
            case 'move'
                onPlayerMove(data);
            case 'draw_card'
                playerDrawCard(client);
            otherwise
                disp('Unknown message type received.');
                write(client, jsonencode(struct('type', 'error', 'message', 'Unknown message type!')), "string");
        end
    end
end

% ========== PLAYER CONNECT ========== %
function onPlayerConnect(client)
    global players;
    global playerHands;
    global playerGameStart;
    players{end+1} = client;
    playerHands{end+1} = drawCards(7); % Draw 7 cards
    disp(['Player ', num2str(numel(players)), ' connected.']);
    write(client, jsonencode(...
    struct(...
        'type', 'welcome', ...
        'message', 'Welcome to UNO!')...
    ), "string"...
    );

    if numel(players) >= playerGameStart
        pause(1);
        broadcastToAll(struct('type', 'start'));
        startGame();
    end
end

% ========== STOP SERVER ========== %
function terminateServer()
    global client;
    global stop;
    global app;
    close(app);
    delete(client); % Delete the tcpserver object from memory 
    delete(app);
    stop = true;
end



% ======================= GAME FUNCTIONS ======================= %

% ========== GAME START ========== %

function playerDrawCard(client)
    global players;
    global playerHands;
    senderIndex = cellfun(@(c) isequal(c, client), players);
    playerHands{senderIndex} = [playerHands{senderIndex};drawCards(1)];
    broadcastGameState()
end


function startGame()
    global discardPile;
    global currentTurn;
    global players;

    discardPile = drawCards(1); % Draw the first card
    broadcastGameState();
end

function broadcastGameState()
    disp("Broadcasting Game State...")
    global players;
    global playerHands;
    global currentTurn
    global discardPile;
    for i = 1:numel(players)
        jsonMessage = jsonencode(struct( ...
            'type', 'game_state', ...
            'deck', table(playerHands{i}), ...
            'discard_pile', table(discardPile), ...
            'turn', currentTurn));
        disp(jsonMessage);
        write(players{i}, jsonMessage, "string");
    end
end

function onPlayerMove(data)
    global currentTurn;
    global discardPile;

    move = data.move;
    disp(['Player ', num2str(currentTurn), ' played: ', move]);

    % Validate the move
    if ~isValidMove(move, discardPile)
        sendToPlayer(currentTurn, struct('type', 'error', 'message', 'Invalid move! Try again.'));
        return;
    end

    % Apply the move
    discardPile{end+1} = move;

    % Handle special cards and advance turn
    handleSpecialCard(move);

    % Check for winner
    if isempty(playerHands{currentTurn})
        broadcastToAll(struct('type', 'game_end', 'message', ...
            ['Player ', num2str(currentTurn), ' wins!']));
        return;
    end

    % Notify the next player
    currentTurn = advanceTurn(currentTurn, numel(players));
    sendToPlayer(currentTurn, struct('type', 'turn', 'message', 'Your turn!'));
end

function handleSpecialCard(move)
    global currentTurn;
    global players;
    global playerHands;
    global mainDeck;
    global discardPile;

    cardType = move{1}; % Get the card type (e.g., Skip, Reverse, etc.)
    switch cardType
        case 'Skip'
            % Skip the next player's turn
            disp('Skip card played!');
            currentTurn = advanceTurn(currentTurn, numel(players)); % Skip the next player

        case 'Reverse'
            % Reverse the turn order
            disp('Reverse card played!');
            players = flip(players); % Flip the players' order
            playerHands = flip(playerHands); % Flip the player hands
            currentTurn = numel(players) - currentTurn + 1; % Adjust the current turn

        case 'Draw Two'
            % Draw two cards for the next player
            nextPlayer = advanceTurn(currentTurn, numel(players));
            playerHands{nextPlayer} = [playerHands{nextPlayer}; drawCards(2)];
            disp(['Player ', num2str(nextPlayer), ' draws two cards!']);
            currentTurn = advanceTurn(nextPlayer, numel(players)); % Skip the next player's turn

        case 'Wild'
            % Let the player choose a new color
            disp('Wild card played! Waiting for color choice...');
            newColor = promptColor(currentTurn); % Prompt for color selection
            discardPile{end, 2} = newColor; % Update the discard pile with the chosen color
            disp(['Player ', num2str(currentTurn), ' chose ', newColor, ' as the new color!']);

        case 'Wild Draw Four'
            % Force the next player to draw four cards and let the player choose a color
            disp('Wild Draw Four card played!');
            nextPlayer = advanceTurn(currentTurn, numel(players));
            playerHands{nextPlayer} = [playerHands{nextPlayer}; drawCards(4)];
            newColor = promptColor(currentTurn); % Prompt for color selection
            discardPile{end, 2} = newColor; % Update the discard pile with the chosen color
            disp(['Player ', num2str(currentTurn), ' chose ', newColor, ' as the new color!']);
            disp(['Player ', num2str(nextPlayer), ' draws four cards!']);
            currentTurn = advanceTurn(nextPlayer, numel(players)); % Skip the next player's turn

        otherwise
            % No special effect for normal cards
            disp('Normal card played.');
            currentTurn = advanceTurn(currentTurn, numel(players)); % Advance to the next player
    end
end


function isValid = isValidMove(move, discardPile)
    % Check if the move is valid
    lastCard = discardPile{end};
    isValid = strcmp(move.color, lastCard.color) || strcmp(move.type, lastCard.type);
end

function deck = createUnoDeck()
    colors = {'Red', 'Green', 'Blue', 'Yellow'};
    cardIDs = {'0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'Skip', 'Reverse', 'Draw Two'};
    deck = [];
    for c = 1:numel(colors)
        for id = 1:numel(cardIDs)
            deck = [deck; {cardIDs{id}, colors{c}}];
            if ~strcmp(cardIDs{id}, '0')
                deck = [deck; {cardIDs{id}, colors{c}}];
            end
        end
    end
    for i = 1:4
        deck = [deck; {'Wild', 'None'}; {'Wild Draw Four', 'None'}];
    end
    deck = deck(randperm(size(deck, 1)), :); % Shuffle the deck
end

function [cards] = drawCards(numCards)
    global mainDeck;
    global discardPile;

    cards = {}; % Initialize drawn cards
    for i = 1:numCards
        if isempty(mainDeck)
            if isempty(discardPile)
                error('Deck and discard pile are empty!');
            end
            % Reshuffle discard pile into deck
            topCard = discardPile(end, :);
            mainDeck = discardPile(1:end-1, :); % Exclude top card
            discardPile = topCard;
            mainDeck = mainDeck(randperm(size(mainDeck, 1)), :); % Shuffle
            disp('Reshuffling discard pile into deck...');
        end
        cards = [cards; mainDeck(1, :)];
        mainDeck(1, :) = []; % Remove the card
    end
end

function nextTurn = advanceTurn(currentTurn, totalPlayers)
    nextTurn = mod(currentTurn, totalPlayers) + 1;
end

function broadcastToAll(data)
    global players;
    jsonMessage = jsonencode(data);
    for i = 1:numel(players)
        write(players{i}, jsonMessage, "string");
    end
end

function sendToPlayer(playerID, data)
    global players;
    jsonMessage = jsonencode(data);
    write(players{playerID}, jsonMessage, "string");
end
