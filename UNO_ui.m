function unoGameUI()
    % Create the main figure
    fig = uifigure('Name', 'Uno Game', 'Position', [100, 100, 800, 600]);

    % Central deck display (discard pile and draw deck)
    discardPile = uilabel(fig, 'Text', 'Discard Pile', ...
        'Position', [350, 275, 100, 100], ...
        'BackgroundColor', 'white', ...
        'HorizontalAlignment', 'center', ...
        'FontWeight', 'bold', 'FontSize', 16);
    
    % Your cards panel (scrollable)
    uilabel(fig, 'Text', 'Your Hand', ...
        'Position', [350, 50, 100, 30], ...
        'HorizontalAlignment', 'center');
    yourHandPanel = uipanel(fig, 'Title', 'Your Cards', ...
        'Position', [200, 50, 400, 150], ... 
        'Scrollable', 'on');
    
    % Draw card button
    drawDeck = uibutton(fig, 'Text', 'Draw Card', ...
        'Position', [650, 75, 75, 75], ...
        'ButtonPushedFcn', @(src, event) drawCardCallback());

    % Labels and boxes for other players
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
    
    % Initialize cards and deck
    deck = {'Red 5', 'Blue Skip', 'Green 2', 'Yellow Reverse', 'Wild Wild', 'Red 3', 'Blue 6', 'Green Skip', 'Yellow 7'};
    yourCards = {'Red 5', 'Blue Skip', 'Green 2', 'Yellow Reverse'};
    renderCards(yourCards);

    % Update other player card counts
    northCardCount.Text = '4 cards';
    eastCardCount.Text = '3 cards';
    westCardCount.Text = '5 cards';

    % Nested function to render cards
    function renderCards(cards)
        % Clear any existing UI elements before re-adding
        delete(allchild(yourHandPanel));  % Remove all child components

        % Loop through the current cards and add them as buttons
        for i = 1:numel(cards)
            [cardColor, cardText] = parseCard(cards{i});
            uibutton(yourHandPanel, ...
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

    % Nested function to play a card
    function playCardCallback(cardButton, cards, cardIndex)
        % Log the card being played
        disp(['You played card: ', cards{cardIndex}]);

        % Update the discard pile with only the type of the card (e.g., '5')
        [cardColor, cardText] = parseCard(cards{cardIndex});
        discardPile.Text = cardText;
        discardPile.BackgroundColor = cardColor;

        % Remove the played card from the hand
        cards = [cards(1:cardIndex-1), cards(cardIndex+1:end)];  % Ensure only the played card is removed

        % Refresh the hand without resetting the entire panel
        renderCards(cards);
        delete(cardButton);  % Remove the button corresponding to the played card
    end

    % Nested function to draw a card
    function drawCardCallback()
        % Randomly draw a card from the deck
        newCard = deck{randi(numel(deck))};
        yourCards{end+1} = newCard;

        % Add a new button for the drawn card at the correct position
        [cardColor, cardText] = parseCard(newCard);
        uibutton(yourHandPanel, ...
            'Text', cardText, ...
            'Position', [(numel(yourCards)-1)*90+10, 30, 80, 50], ...  % Position new card at the end
            'BackgroundColor', cardColor, ...
            'HorizontalAlignment', 'center', ...
            'FontWeight', 'bold', ...
            'FontSize', 14, ...
            'UserData', numel(yourCards), ...
            'ButtonPushedFcn', @(src, event) playCardCallback(src, yourCards, numel(yourCards)));

        % Display message for the drawn card
        disp(['You drew a card: ', newCard]);
    end

    % Helper function to parse a card
    function [color, text] = parseCard(card)
        cardParts = strsplit(card);
        color = cardParts{1};
        text = cardParts{2};
        
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
