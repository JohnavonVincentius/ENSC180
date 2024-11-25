% UNO Game Server with JSON Transport
port = 55000;
server = tcpserver('0.0.0.0', port, 'ConnectionAcceptedFcn', @onPlayerConnected);

disp('UNO Server started. Waiting for players to connect...');

% Game state variables
players = {};
playerHands = {};
deck = createUnoDeck();
discardPile = [];
currentTurn = 1;

% Callback function when a player connects
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
