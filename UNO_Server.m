disp('Initializing Game States...');
initGameState('0.0.0.0' , 55500)        %Init Server and GameStates (BIND,PORT)
disp('UNO Server started. Waiting for players to connect...');
% ================== PRIMARY MAIN FUNCTION ================== %
while true
    main()
    pause(0.1); % Prevent busy waiting
end
% ================== ===================== ================== %

function main()
    if server.Connected
        % Read incoming data
        if server.NumBytesAvailable > 0
            onSRVReceive(server)
        end
    end
end

function initGameState(bind, port)
    global players
    global mainDeck
    global discardPile
    global currentTurn
    global server

    server = tcpserver(bind, port); % Create the TCP server

    players = {};
    mainDeck = createUnoDeck();
    discardPile = [];
    currentTurn = 1;
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

function [cards] = drawCards (numCards)
    % Function to draw cards from the deck with unlimited capacity
    cards = {}; % Initialize the drawn cards

    for i = 1:numCards
        % If the deck is empty, reshuffle the discard pile back into the deck
        if isempty(mainDeck)
            if isempty(discardPile)
                error('Deck and discard pile are empty! Cannot draw more cards.');
            end
            % Reshuffle the discard pile into the deck (leave the top card)
            topCard = discardPile(end, :);
            mainDeck = discardPile(1:end-1, :); % Take all but the top card
            discardPile = topCard; % Keep the top card as the discard pile
            mainDeck = mainDeck(randperm(size(mainDeck, 1)), :); % Shuffle the deck
            disp('Reshuffling discard pile into deck...');
        end

        % Draw the top card from the deck
        cards = [cards; mainDeck(1, :)]; % Add the top card to the drawn cards
        mainDeck(1, :) = []; % Remove the drawn card from the deck
    end
end

function onSRVReceive(server)
    jsonData = read(server, server.NumBytesAvailable, "string");
    data = jsondecode(jsonData);
    % Handle different types of messages
    if isfield(data, 'type')
        switch data.type
            case 'connect'
                % Player connection
                players{end+1} = server; % Add player to the list
                playerData{end+1} = struct('id', numel(players), 'hand', []);
                disp(['Player ', num2str(numel(players)), ' connected.']);
                write(server, jsonencode(struct('type', 'welcome', 'message', 'Welcome to UNO!')), "string");

                if numel(players) > 1
                    broadcastToAll(struct('type', 'start', 'message', 'Game is starting!'));
                    startGame();
                end


            case 'move'
                % Process player move
                disp(['Player move: ', data.move]);
                write(server, jsonencode(struct('type', 'response', 'message', 'Move received!')), "string");

            otherwise
                % Unknown message type
                disp('Unknown message type received.');
                write(server, jsonencode(struct('type', 'error', 'message', 'Unknown message type!')), "string");
        end
    end
end

function onPlayerConnected(src, ~)
    disp('A new player has connected.');
    players{end+1} = src;
    playerHands{end+1} = drawCards(deck, 7);
    if numel(players) > 1
        broadcastToAll(struct('type', 'start', 'message', 'Game is starting!'));
        startGame();
    end
end

% Function to start the game
function startGame()
    discardPile = [discardPile; drawCards(deck, 1)];
    broadcastToAll(struct('type', 'game_update', 'message', ...
        ['Starting card is: ', discardPile{end}], 'discard_pile', discardPile));
    sendToPlayer(currentTurn, struct('type', 'turn', 'message', 'Your turn!'));
end

% Function to process a player's move
function processMove(playerID, jsonData)
    move = jsonData.move; % Read the move from JSON
    disp(['Player ', num2str(playerID), ' played: ', move]);

    % Validate move
    if ~isValidMove(move, discardPile)
        sendToPlayer(playerID, struct('type', 'error', 'message', 'Invalid move! Try again.'));
        return;
    end

    % Apply the move
    discardPile{end+1} = move;
    playerHands{playerID}(strcmp(playerHands{playerID}, move)) = [];
    broadcastToAll(struct('type', 'game_update', 'message', ...
        ['Player ', num2str(playerID), ' played: ', move], 'discard_pile', discardPile));

    % Handle special cards and update turn
    handleSpecialCard(playerID, move);

    % Check for winner
    if isempty(playerHands{playerID})
        broadcastToAll(struct('type', 'game_end', 'message', ...
            ['Player ', num2str(playerID), ' wins!']));
        return;
    end

    % Notify the next player
    sendToPlayer(currentTurn, struct('type', 'turn', 'message', 'Your turn!'));
end

% Function to handle special cards
function handleSpecialCard(playerID, move)
    % Process special cards as described earlier
    % (e.g., Skip, Reverse, Draw Two, Wild, Wild Draw Four)
end

% JSON message broadcasting
function broadcastToAll(data)
    jsonMessage = jsonencode(data);
    for i = 1:numel(players)
        write(players{i}, jsonMessage, "string");
    end
end

% JSON message sending to a specific player
function sendToPlayer(playerID, data)
    jsonMessage = jsonencode(data);
    write(players{playerID}, jsonMessage, "string");
end
