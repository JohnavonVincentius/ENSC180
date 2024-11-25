% UNO Game Client with JSON Transport
serverIP = '127.0.0.1';
port = 55000;

disp('Connecting to UNO server...');
client = tcpclient(serverIP, port);
disp('Connected to UNO server.');

% Listen for messages from the server
while true
    if client.NumBytesAvailable > 0
        jsonData = read(client, client.NumBytesAvailable, "string");
        data = jsondecode(jsonData); % Decode JSON message
        disp(['Server: ', data.message]);

        % If it's the player's turn, send a move
        if strcmp(data.type, 'turn')
            % Example move, this would be dynamic in a real game
            playerMove = struct('type', 'move', 'move', 'Red 5');
            jsonMessage = jsonencode(playerMove);
            write(client, jsonMessage, "string");
            disp(['Sent move to server: ', playerMove.move]);
        end
    end
    pause(0.1); % Prevent busy-waiting
end
