clear all;

% =================== SERVER CONFIGURATION ================== %
global playerGameStart;
SERVER_ADDR = "0.0.0.0";
playerGameStart = 2;

% ================== SERVER INITIALIZATION ================== %
disp('Initializing Game States...');
global players;
global playerHands;
global mainDeck;
global discardPile;
global currentTurn;
global client_1;
global client_2;
global client_3;
global client_4;
global t

global app;

client_1 = tcpserver(SERVER_ADDR, 55000, 'ConnectionChangedFcn', @handleClient);
client_2 = tcpserver(SERVER_ADDR, 55100, 'ConnectionChangedFcn', @handleClient);
client_3 = tcpserver(SERVER_ADDR, 55200, 'ConnectionChangedFcn', @handleClient);
client_4 = tcpserver(SERVER_ADDR, 55300, 'ConnectionChangedFcn', @handleClient);
t = timer;
t.ExecutionMode = 'fixedRate';
t.Period = 1;
t.TimerFcn = @broadcastGameState; % Function with limit
start(t);


app = uifigure('Name', 'Uno Game Server Console', 'Position', [100, 100, 600, 400]);
uibutton(app, 'Text', 'Terminate Server', ...
    'Position', [450, 20, 120, 40], ...
    'ButtonPushedFcn', @(btn, event) terminateServer());

uibutton(app, 'Text', 'Broadcast State', ...
'Position', [10, 20, 100, 50], ...
'ButtonPushedFcn', @(btn, event) broadcastGameState());

uibutton(app, 'Text', 'Start Game', ...
'Position', [10, 50, 100, 50], ...
'ButtonPushedFcn', @(btn, event) startGame());


players = [];
playerHands = [];
mainDeck = createUnoDeck();
discardPile = [];
currentTurn = 1;

disp('UNO Server started. Waiting for players to connect...');

function handleClient(server, ~)
    % Read and respond to the client
    if server.Connected
        % Read incoming data
        if server.NumBytesAvailable > 0
            onSRVReceive(server);
        end
    end
    pause(0.1);
end

% ================== PRIMARY MAIN FUNCTION ================== %
global stop_service;
while true
    try
        main(client_1);
        main(client_2);
        main(client_3);
        main(client_4);
    catch exception
        disp("Error: " + exception.message);
    end
    pause(0.1); % Prevent busy waiting
    if stop_service == true
        break
    end
end

% ======================= SERVER FUNCTIONS ======================= %

% ========== SERVER MAIN ========== %
% The main fuction that will run in a loop.
function main(client)
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
                onPlayerMove(client,data);
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
        'message', 'Welcome to UNO!', ...
        'player',find(cellfun(@(c) isequal(c, client), players)))...
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
    global client_1;
    global client_2;
    global client_3;
    global client_4;
    global t;
    global stop_service;
    global app;
    stop_service = true;

    close(app);
    delete(client_4); % Delete the tcpserver object from memory 
    delete(client_3);
    delete(client_2);
    delete(client_1);
    stop(t);
    delete(t);
    delete(app);
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

    discardPile{1} = drawCards(1); % Draw the first card
    broadcastGameState();
end

function broadcastGameState(~,~)
try
    disp("Broadcasting Game State...")
    global players;
    global playerHands;
    global currentTurn
    global discardPile;
    player = size(players)
    numCards = cellfun(@(x) size(x, 1), playerHands)
    for i = 1:numel(players)
        jsonMessage = jsonencode(struct( ...
            'type', 'game_state', ...
            'deck', table(playerHands{i}), ...
            'discard_pile', table(discardPile{end}), ...
            'turn', currentTurn, ...
            'cards', table(player,numCards)...
            ));
        disp(jsonMessage);
        write(players{i}, jsonMessage, "string");
    end
catch exeption
    disp(exeption)
end
end

function onPlayerMove(client,data)
    global currentTurn;
    global discardPile;
    global playerHands;
    global players;

    if client ~= players{currentTurn}
        write(client, jsonencode(struct('type', 'error', 'message', 'Invalid move! Try again.')),"string");
        return;
    end

    move = transpose(data.move.Var1);
    disp(['Player ', num2str(currentTurn), ' played: ', move]);

    % Validate the move
    if ~isValidMove(move, discardPile)
        sendToPlayer(currentTurn, struct('type', 'error', 'message', 'Invalid move! Try again.'));
        return;
    end

    discardPile{end+1} = move;
    
    for i = 1:size(playerHands{currentTurn}, 1)
        % Check if the current row matches the target
        if isequal(playerHands{currentTurn}(i, :), move)
            % Remove the row by excluding it
            playerHands{currentTurn} = [playerHands{currentTurn}(1:i-1, :); playerHands{currentTurn}(i+1:end, :)];
            break; % Exit after the first match
        end
    end

    handleSpecialCard(move);


    broadcastGameState();

    % Check for winner
    if isempty(playerHands{currentTurn})
        broadcastToAll(struct('type', 'game_end', 'message', ...
            ['Player ', num2str(currentTurn), ' wins!']));
        return;
    end

    % Notify the next player
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

        case 'Wild Draw Four'
            % Force the next player to draw four cards and let the player choose a color
            disp('Wild Draw Four card played!');
            nextPlayer = advanceTurn(currentTurn, numel(players));
            playerHands{nextPlayer} = [playerHands{nextPlayer}; drawCards(4)];
            discardPile{end, 2} = newColor; % Update the discard pile with the chosen color
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
    lastCard = discardPile(end);

    if strcmp(move{1,2}, 'None') || strcmp( lastCard{1}{1,2} ,'None');
        isValid = true;
        return;
    end
    isValid = strcmp(move{1,1}, lastCard{1}{1,1}) || strcmp(move{1,2}, lastCard{1}{1,2});
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

%#ok<*GVMIS>