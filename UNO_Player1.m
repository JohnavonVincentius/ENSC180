clear all;

% =================== CLIENT CONFIGURATION ================== %
serverIP = '127.0.0.1';
server_PORTS = [55000,55100,55200,55300];
% ================== CLIENT INITIALIZATION ================== %
disp('Connecting to UNO server...');
global server;
global deck;
global discardPile;
global currentTurn;
serverConnected = false;


for i = i:length(server_PORTS)
    try
        server = tcpclient(serverIP, server_PORTS(i));
        write(server, jsonencode(struct('type', 'connect')), "string");
        tic;
        while toc < 2
            if server.NumBytesAvailable > 0
                response = jsondecode(read(server, server.NumBytesAvailable, "string"))
                if response.type == 'welcome'
                    disp("Connected to UNO Server, Waiting for players...")
                    serverConnected = true;
                    break;
                end
            end
        end
    catch exception
    end

    if serverConnected == false
        disp("Failed to connect to server, retrying on different port")
    else
        disp("Connected using port:" + server_PORTS(i))
        break;
    end
end

if serverConnected == true
    setupUI()
end

% ================== PRIMARY MAIN FUNCTION ================== %
global stop;
while serverConnected
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


% The main fuction that will run in a loop.
function main()
    global server;
    if server.NumBytesAvailable > 0
        onSRVReceive(server);
    end
end

function onSRVReceive(client)
    jsonData = read(client, client.NumBytesAvailable, "string");
    data = jsondecode(jsonData);
    if isfield(data, 'type')
        switch data.type
            case 'start'
                startGame();
            case 'game_state'
                processGameState(data);
                renderUI()
            otherwise
                disp('Unknown message type received.');
        end
    end
    clear data;
end

function startGame()
    disp("Starting Game!!");
end

function processGameState(decodedStruct)
    global deck;
    global discardPile;
    global currentTurn;

    dataStructArray = decodedStruct.deck;
    
    % Initialize an empty cell array
    numRows = numel(dataStructArray);
    cellArray = cell(numRows, 2); % Assume two columns for the cell array

    % Populate the cell array from the structure array
    for i = 1:numRows
        cellArray(i, :) = dataStructArray(i).Var1;
    end

    discardPile = decodedStruct.discard_pile.Var1;
    deck = cellArray;
    currentTurn = decodedStruct.turn;

    disp(deck);
end


function renderUI()
    global discardPileUI
    global yourHandPanel
    global northCardCount
    global eastCardCount
    global westCardCount
    global deck
    global discardPile

    discardPileUI.Text = discardPile(1);
    
    switch discardPile{2}
        case 'Red'
            color = [1, 0, 0];  % Red
        case 'Blue'
            color = [0, 0, 1];  % Blue
        case 'Green'
            color = [0, 1, 0];  % Green
        case 'Yellow'
            color = [1, 1, 0];  % Yellow
        case 'Wild'
            color = [0.5, 0.5, 0.5];  % Gray for Wild
        otherwise
            color = [1, 1, 1];  % Default white
    end

    discardPileUI.BackgroundColor = color;

    % Clear any existing UI elements before re-adding
    delete(allchild(yourHandPanel));  % Remove all child components
    % Loop through the current cards and add them as buttons
    for i = 1:numel(deck)

                    switch deck{i,2}
            case 'Red'
                color = [1, 0, 0];  % Red
            case 'Blue'
                color = [0, 0, 1];  % Blue
            case 'Green'
                color = [0, 1, 0];  % Green
            case 'Yellow'
                color = [1, 1, 0];  % Yellow
            case 'Wild'
                color = [0.5, 0.5, 0.5];  % Gray for Wild
            otherwise
                color = [1, 1, 1];  % Default white
                    end

        uibutton(yourHandPanel, ...
            'Text', deck{i,1}, ...
            'Position', [(i-1)*90+10, 30, 80, 50], ...
            'BackgroundColor', color, ...
            'HorizontalAlignment', 'center', ...
            'FontWeight', 'bold', ...
            'FontSize', 14, ...
            'UserData', i, ...
            'ButtonPushedFcn', @(src, event) playCardCallback(deck, i));
    end
    % discardPileUI.Text = discardPile.discardPile(1);

end

function playCardCallback(cards, cardIndex)
    global server;
    write(server, jsonencode(struct('type','move', 'move', table(cards(cardIndex,:)) )))
end

function drawCardCallback()
    global server
    write(server, jsonencode(struct('type','draw_card')))
end

% ========== UI Setup ========== %
function setupUI()
    global discardPileUI
    global fig
    global yourHandPanel
    global northCardCount
    global eastCardCount
    global westCardCount
    
    fig = uifigure('Name', 'Uno Game', 'Position', [100, 100, 800, 600]);

    discardPileUI = uilabel(fig, 'Text', 'Discard Pile', ...
        'Position', [350, 275, 100, 100], ...
        'BackgroundColor', 'white', ...
        'HorizontalAlignment', 'center', ...
        'FontWeight', 'bold', 'FontSize', 16);

    uilabel(fig, 'Text', 'Your Hand', ...
        'Position', [350, 50, 100, 30], ...
        'HorizontalAlignment', 'center');

    yourHandPanel = uipanel(fig, 'Title', 'Your Cards', ...
        'Position', [200, 50, 400, 150], ... 
        'Scrollable', 'on');

    uibutton(fig, 'Text', 'Draw Card', ...
        'Position', [650, 75, 75, 75], ...
        'ButtonPushedFcn', @(src, event) drawCardCallback());
    
    northBox = uipanel(fig, 'Position', [350, 450, 100, 100], 'BackgroundColor', [0.8 0.8 0.8]);
    northLabel = uilabel(northBox, 'Text', 'Player 3', ...
        'Position', [10, 60, 80, 30], 'HorizontalAlignment', 'center');
    northCardCount = uilabel(northBox, 'Text', '0 cards', ...
        'Position', [10, 10, 80, 30], 'HorizontalAlignment', 'center');
    
    eastBox = uipanel(fig, 'Position', [625, 275, 100, 100], 'BackgroundColor', [0.8 0.8 0.8]);
    eastLabel = uilabel(eastBox, 'Text', 'Player 4', ...
        'Position', [10, 60, 80, 30], 'HorizontalAlignment', 'center');
    eastCardCount = uilabel(eastBox, 'Text', '0 cards', ...
        'Position', [10, 10, 80, 30], 'HorizontalAlignment', 'center');
    
    westBox = uipanel(fig, 'Position', [75, 275, 100, 100], 'BackgroundColor', [0.8 0.8 0.8]);
    westLabel = uilabel(westBox, 'Text', 'Player 2', ...
        'Position', [10, 60, 80, 30], 'HorizontalAlignment', 'center');
    westCardCount = uilabel(westBox, 'Text', '0 cards', ...
        'Position', [10, 10, 80, 30], 'HorizontalAlignment', 'center');  
end