function multiClientTCPServer()
    % Create a server to listen for incoming connections
    mainServer = tcpserver('127.0.0.1', 55000, 'ConnectionChangedFcn', @connectionHandler);

    % Display a message
    disp('Server is listening for connections...');
end

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

function handleClient(server)
    % Read and respond to the client
    write(server, jsonencode(...
      struct(...
          'type', 'welcome', ...
          'message', 'Welcome to UNO!')...
      ), "string"...
      );
    while server.Connected
        if server.BytesAvailable > 0
            % Read the data from the client
            data = readline(server);

            % Display the received data
            disp(['Received: ', data]);

            % Respond to the client
            writeline(server, ['Echo: ', data]);
        end

        % Add a short pause to avoid high CPU usage
        pause(0.1);
    end

    disp('Client handling completed.');
end
