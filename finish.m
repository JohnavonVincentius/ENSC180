global client;
fclose(client); % Close the socket explicitly 
delete(client); % Delete the tcpserver object from memory 
disp("Exiting...");