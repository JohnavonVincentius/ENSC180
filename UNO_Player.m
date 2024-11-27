clear all;

% =================== CLIENT CONFIGURATION ================== %
serverIP = '127.0.0.1';
port = 5050;

% ================== CLIENT INITIALIZATION ================== %
disp('Connecting to UNO server...');
global server;
global deck;
global discardPile;
global currentTurn;
serverConnected = false;

try
    server = tcpclient(serverIP, port);
    write(server, jsonencode(struct('type', 'connect')), "string");
    tic;
    while toc < 10
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
    disp("Error"+ exception.message)
end

if serverConnected == false
    disp("Failed to connect to server")
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

    discardPile = decodedStruct.discard_pile
    deck = cellArray;
    currentTurn = decodedStruct.turn;

    disp(deck);
end
