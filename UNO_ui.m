function unoGameUI()
    % Create the main figure
    try
        fig = uifigure('Name', 'Uno Game', 'Position', [100, 100, 800, 600]);
    catch
        error('Unable to create the main figure. Ensure you are using a MATLAB version that supports uifigure.');
    end

    % Central deck display (discard pile and draw deck)
    try
        % Discard pile in the center, larger than other UI components
        discardPile = uilabel(fig, 'Text', 'Discard Pile', ...
            'Position', [350, 300, 100, 100], ...
            'BackgroundColor', 'white', ...
            'HorizontalAlignment', 'center', ...
            'FontWeight', 'bold', 'FontSize', 16);
        
        % Draw label for the central deck
        uilabel(fig, 'Text', 'Central Deck', ...
            'Position', [350, 400, 100, 30], ...
            'HorizontalAlignment', 'center');
        
    catch
        error('Error creating central deck UI elements.');
    end

    % Your cards panel (scrollable)
    try
        uilabel(fig, 'Text', 'Your Hand', ...
            'Position', [350, 50, 100, 30], ...
            'HorizontalAlignment', 'center');
        
        yourHandPanel = uipanel(fig, 'Title', 'Your Cards', ...
            'Position', [200, 50, 400, 100], ...
            'Scrollable', 'on');
    catch
        error('Error creating your hand panel.');
    end

    % Draw card button (positioned to the right of "Your Cards")
    try
        drawDeck = uibutton(fig, 'Text', 'Draw Card', ...
            'Position', [610, 50, 100, 50], ... % Adjusted position
            'ButtonPushedFcn', @(src, event) drawCardCallback());
    catch
        error('Error creating the draw card button.');
    end

    % Labels for other players (Positioned around the central discard pile)
    % North Player
    northLabel = uilabel(fig, 'Text', 'North Player: 0 cards', ...
        'Position', [350, 450, 100, 30], ...
        'HorizontalAlignment', 'center');
    
    % East Player
    eastLabel = uilabel(fig, 'Text', 'East Player: 0 cards', ...
        'Position', [700, 250, 100, 30], ...
        'HorizontalAlignment', 'center');
    
    % South Player
    southLabel = uilabel(fig, 'Text', 'South Player: 0 cards', ...
        'Position', [350, 150, 100, 30], ...
        'HorizontalAlignment', 'center');
    
    % West Player
    westLabel = uilabel(fig, 'Text', 'West Player: 0 cards', ...
        'Position', [100, 250, 100, 30], ...
        'HorizontalAlignment', 'center');
    
    % Initialize player's cards
    try
        yourCards = {'Red 5', 'Blue Skip', 'Green 2', 'Yellow Reverse'};
        
        % Debugging output to check the cards before rendering
        disp('Your Cards:');
        disp(yourCards);
        
        % Call renderCards
        renderCards(yourCards, yourHandPanel);
    catch e
        disp('Error rendering your cards:');
        disp(e.message);
    end

    % Initialize other players' cards (random counts for demonstration)
    northCards = 4;   % Example number of cards
    eastCards = 3;    % Example number of cards
    southCards = 5;   % Example number of cards
    westCards = 5;    % Example number of cards
    
    % Update other player labels with their card count
    northLabel.Text = ['North Player: ', num2str(northCards), ' cards'];
    eastLabel.Text = ['East Player: ', num2str(eastCards), ' cards'];
    southLabel.Text = ['South Player: ', num2str(southCards), ' cards'];
    westLabel.Text = ['West Player: ', num2str(westCards), ' cards'];

    % Nested function to render cards
    function renderCards(cards, panel)
        % Clear any old UI components that are children of the panel
        children = allchild(panel);  % Get the children components of the panel
        if ~isempty(children)
            delete(children);  % Remove the old card buttons
        end

        % Create card buttons dynamically for each card in the hand
        for i = 1:numel(cards)
            if ~isempty(cards{i})  % Ensure that the card is not empty
                [cardColor, cardText] = parseCard(cards{i});
                cardButton = uibutton(panel, ...
                    'Text', cardText, ...
                    'Position', [(i-1)*90+10, 30, 80, 50], ...
                    'BackgroundColor', cardColor, ...
                    'HorizontalAlignment', 'center', ...
                    'FontWeight', 'bold', ...
                    'FontSize', 14, ...
                    'UserData', i, ...
                    'ButtonPushedFcn', @(src, event) playCardCallback(src, cards, i));
            end
        end
    end

    % Nested function to play a card
    function playCardCallback(cardButton, cards, cardIndex)
        % Log the card being played (without accessing the button)
        disp(['You played card: ', cards{cardIndex}]);

        % Update the discard pile
        discardPile.Text = cards{cardIndex};
        discardPile.BackgroundColor = cardButton.BackgroundColor;

        % Remove the played card from the hand (logical data update)
        cards{cardIndex} = []; % Mark card as played
        cards = cards(~cellfun('isempty', cards)); % Clean up array

        % Refresh the hand
        renderCards(cards, yourHandPanel);

        % Delete the played card's button from the UI
        delete(cardButton);  % Delete the button corresponding to the played card
    end

    % Nested function to draw a card
    function drawCardCallback()
        % Define a simple deck of cards for drawing
        possibleCards = {'Red 5', 'Blue Skip', 'Green 2', 'Yellow Reverse', 'Wild Card'};
        
        % Randomly pick a card from the deck
        newCard = possibleCards{randi(numel(possibleCards))};
        
        % Add the drawn card to your hand
        yourCards{end+1} = newCard;
        
        % Refresh the hand with the new card
        renderCards(yourCards, yourHandPanel);
        
        % Debugging output to indicate the drawn card
        disp(['You drew a card: ', newCard]);
    end

    % Helper function to parse a card string and return its color and text
    function [color, text] = parseCard(card)
        cardParts = strsplit(card);
        color = cardParts{1};  % Extract the color
        text = cardParts{2};   % Extract the card value (number/ability)
        
        % Set background color based on card color
        switch color
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
    end
end
