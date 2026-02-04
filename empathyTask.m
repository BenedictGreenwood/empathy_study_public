%% Script for empathy for pain task

function empathyTask()
clear
clc

%% Test audio tone
% Parameters for the tone
fs = 44100; % Sampling frequency in Hz
duration = 0.2; % Duration of the tone in seconds
frequency = 1000; % Frequency of the tone in Hz (A4 note)

% Generate the time vector
t = 0:1/fs:duration;

% Generate the sine wave tone
tone = sin(2 * pi * frequency * t);

% Play the tone
sound(tone, fs);

%% Define whether digitimer is connected or not
digitimerConnected = true; %editme - define whether digitimer is connected or not.
sendTextMarks = true; %editme - define whether to send textmarks over serial line to data collection laptop
serialOut = "COM3"; %editme - select com port for sending messages (textmarks) to laptop running Spike2

%define task folder - editme - change depending on which computer you are running task on
taskFolder = 'C:\Users\Experimenter\Desktop\ADHD emotion testing\Empathy study\Empathy Task';
%taskFolder = 'N:\Documents\PhD\2nd year\Task code and stimuli\Empathy task DEVELOPMENT';
%taskFolder = 'C:\Users\44793\Downloads';

%define task folder for stimuli
taskFolderStimuli = [ taskFolder '/'  'stimuli'];

%% Set up serial line to send TextMarks from stimulus laptop to data collection laptop

if sendTextMarks == true
    textMarkStop = ';'; %editme - terminator for TextMarks. Must align with settings in TextMark channel in Spike2
    serialPort = serialport(serialOut,9600); %editme - IMPORTANT specify which COM port is serial port and open serial line

    %define textmarks
    mark.taskStart = ['t01' textMarkStop]; %start of task
    mark.shockPworkup = ['spw' textMarkStop]; %shock delivered to participant during workup
    mark.shockCworkup = ['scw' textMarkStop]; %shock delivered to companion during workup
    mark.blockStart = ['blk' textMarkStop]; %start of block
    mark.antPreName = ['apr' textMarkStop]; %start of anticipation period before name is displayed
    mark.antPostName = ['apo' textMarkStop]; %start of anticipation period after name is displayed
    mark.shockPhigh = ['sph' textMarkStop]; %high shock delivered to participant during main task
    mark.shockPlow = ['spl' textMarkStop]; %low shock delivered to participant during main task
    mark.shockPsafe = ['sps' textMarkStop]; %safe shock delivered to participant during main task
    mark.shockChigh = ['sch' textMarkStop]; %high shock delivered to companion during main task
    mark.shockClow = ['scl' textMarkStop]; %low shock delivered to companion during main task
    mark.shockCsafe = ['scs' textMarkStop]; %safe shock delivered to companion during main task
    mark.responsePeriod = ['res' textMarkStop]; %start of response period during main task
    mark.submitRatings = ['rat' textMarkStop]; %start of participant/companion prompted to submit rating
    mark.endTrial = ['ten' textMarkStop]; %end of trial
    mark.taskEnd = ['t02' textMarkStop]; %end of task

else %if you are not sending textmarks via the serialport then set to empty
    serialPort = [];
end

%% Enter participat ID

% Start the task
if sendTextMarks == true
    write(serialPort, mark.taskStart, "string"); %send textmark for start of task
end

%get experimenter to enter user ID in gui
validInput = false;

while validInput == false
    participantID = input('Enter participant ID in format ''EB001'' or ''EB001'': ', 's');
    companionID = [participantID 'C'];

    if length(participantID) == 5 && isnumeric(str2double(participantID(3:5) ))
        validInput = true;
    end
end

participantID = [participantID 'P']; %add p to end of participant ID

try
    %% Define useful variables

    %block/trial numbers
    nTrialsPerCondPerP = [16 16 8]; %editme - num trials per shock condition per participant (high - low - safe)
    nBlocks = 16; %editme - number of blocks
    nTrialsPerBlock = sum(2 * nTrialsPerCondPerP)/nBlocks ;
    iblocksWithRatings = [4 8 12];


    %timing
    durationAnticipationPreName = 3; %editme - duration of anticipation period before shock recipient name has appeared on screen (seconds)
    durationAnticipationPostName = [6 10]; %editme - jittered duration of anticipation period once shock recipient name has appeared on screen (seconds)
    durationResponse = 6; %editme - duration of response period once person has been shocked

    %aesthetics
    white = [1 1 1];
    black = [0 0 0];
    textSizeMed = 40; %editme - medium text size
    textSizeBig = 80; %editme - large text size

    %% Define images for each shock condition to use for anticipation

    shockConds = {'high', 'low', 'safe'}; %shock conditions
    shockStimuliColours = {'grey', 'white', 'beige'}; %colours of shock intensity image stimuli

    %randomise colour of shock message
    rng('shuffle') %set random seed to ensure different order each time
    shockStimuliColours = shockStimuliColours(randperm(length(shockStimuliColours))); %randomise order of colours

    %contruct file name of stimuli images
    highShockImgFile = [taskFolderStimuli '/' 'high_' shockStimuliColours{1} '.jpg']; %high shock - take first colour
    lowShockImgFile = [taskFolderStimuli '/' 'low_' shockStimuliColours{2} '.jpg']; %low shock - take second colour
    safeShockImgFile = [taskFolderStimuli '/' 'safe_' shockStimuliColours{3} '.jpg']; %safe - take third colour

    %% initialize and configure parallel port

    %set number of shocks to be sent in a train
    nreps = 5; %editme - IMPORTANT
    waitTimeBetweenShocks = 0.1; %editme - duration between shocks in seconds

    %if digitimer is connected
    if  digitimerConnected == true
        addpath("C:\Program Files\MATLAB\R2022b") %add matlab path to access io64 function
        ioObj = io64; %create object for writing to parallel port
        addpath("C:\Windows\SysWOW64") %add system folder to path
        %addpath("C:\Windows\System32")  %add system folder to path
        status = io64(ioObj); %open parallel port
        adress = hex2dec('3FF8'); %editme - define address of parallel port on your computer

        %define parallel port byte and pin number for participant and companion
        byteParticipant = 1;
        pinNoParticipant = 1;
        byteCompanion = 2;
        pinNoCompanion = 2;

    end


    %% Get trial order from csv files

    participantNo = str2double(participantID(3:5));

    if(mod(participantNo,2)==1) %if participant number is odd
        filepathTrialOrder = [taskFolder '/' 'trialOrderOdds.csv'];
    elseif(mod(participantNo,2)==0)  %else if participant number is even
        filepathTrialOrder = [taskFolder '/' 'trialOrderEvens.csv'];
    end

    %import trial order
    trialOrderTable = readtable(filepathTrialOrder, VariableNamingRule="preserve");

    %% Generate order of observer conditions for each block
    observerConds = {'intensityhidden', 'intensityvisible'}; %define conditions for whether observer sees shock intensity or not
    observerConds = observerConds(randperm(length(observerConds))); %randomise order of conditions
    observerCondsPerBlock = repmat(observerConds, 1, nBlocks / length(observerConds)); %repeat conditions in alternatingly for n blocks


    %% Calculate trials where subjects submit ratings
    ratingFreq = 2; %editme - Set rating frequency (every n instances of a shock condition)
    idxRatingP = NaN(10, numel(shockConds));
    idxRatingC = NaN(10, numel(shockConds));

    for i_cond = 1:numel(shockConds)
        condition = shockConds{i_cond};
        idxP = find(strcmp(trialOrderTable.Participant, condition)); %get indices of condition in Participant col
        idxC = find(strcmp(trialOrderTable.Companion, condition)); %get indices of condition in Companion col
        idxRatingP(1:numel(idxP(1:ratingFreq:end)),i_cond) = idxP(1:ratingFreq:end); % Every nth instance
        idxRatingC(1:numel(idxC(1:ratingFreq:end)), i_cond) = idxC(1:ratingFreq:end); % Every nth instance
    end; clear i_cond

    %collapse into single col
    idxRatingTrials = [idxRatingP(:); idxRatingC(:)];

    %remove NaNs and reorder
    idxRatingTrials = idxRatingTrials(~isnan(idxRatingTrials));
    idxRatingTrials = sort(idxRatingTrials);

    clear idxRatingP idxRatingC condition idxP idxC

    %% Ask for participant and companion names in a pop up gui
    promptAll = {'Participant Name:',  ... %define prompts for text entry boxes in the gui
        'Companion Name:'};
    dlgtitleAll = 'Enter Names';
    dimsAll = [1 100]; % Set the width of the input fields
    definputAll = {'', '', }; % Default values

    allValues = inputdlg(promptAll, dlgtitleAll, dimsAll, definputAll); %display gui and get user input

    % Check if the user clicked 'Cancel'
    if isempty(allValues)
        disp('User cancelled');
        return; % or exit the script
    end

    % Access values as a cell array
    nameParticipant = upper(allValues{1}); %participant name in capitals
    nameCompanion = upper(allValues{2}); %companion name in capitals

    %% Psychtoolbox setup
    PsychDefaultSetup(2);
    %Screen('Preference', 'SkipSyncTests', 0); % Skip sync tests for faster execution

    opacity = 1; %editme - Make our window transparent 0 (transparent) to 1 (opaque)
    PsychDebugWindowConfiguration([], opacity)

    %get screen number of screen 1 and 2
    screenNumber1 = max(Screen('Screens'));
    screenNumber2 = max(Screen('Screens')) - 1;

    %open one psychtoolbox window on each screen
    [windowP, windowRectP] = PsychImaging('OpenWindow', screenNumber1, [0 0 0]);
    [windowC, windowRectC] = PsychImaging('OpenWindow', screenNumber2, [0 0 0]);

    window2scalingFactor = windowRectC / windowRectP;

    %set font size
    Screen('TextSize', windowP, textSizeMed);
    Screen('TextSize', windowC, textSizeMed);
    %% Display messages for checking each person is being shown the correct screen
    %define textbox and button dimensions
    textBoxWidth = 0.25*windowRectP(3); %text box width
    textBoxHeight = 0.2*windowRectP(3); %text box height
    startBoxRect = [0.5*windowRectP(3)-textBoxWidth/2, 0.5*windowRectP(4)-textBoxHeight/2 ,...
        0.5*windowRectP(3)+textBoxWidth/2, 0.5*windowRectP(4)+textBoxHeight/2  ]; %start box position
    lowerButtonRect = [startBoxRect(1), 0.8*windowRectP(4), startBoxRect(3), 0.9*windowRectP(4)]; %position of button at bottom of screen

    pMessage = ['This should be ' nameParticipant '’S screen' ];
    cMessage = ['This should be ' nameCompanion '’S screen' ];
    DrawFormattedText(windowP, pMessage, 'center', 'center', [1 1 1]);
    DrawFormattedText(windowC, cMessage, 'center', 'center', [1 1 1]);
    Screen('Flip', windowP);
    Screen('Flip', windowC);
    waitTimeNamescreen = 5;
    WaitSecs(waitTimeNamescreen);

    %% Workup

    %define which button to use to shock participant or companion
    keyToShockParticipant = 'a';
    keyToShockCompanion = 'l';

    %define workup instructions for participant
    workupInstructs = ['SHOCK WORKUP'...
        '\n\n Experimenter press ' '"' upper(keyToShockParticipant) '"' ' to shock ' nameParticipant ...
        '\n\n Experimenter press ' '"' upper(keyToShockCompanion) '"' ' to shock ' nameCompanion ...
        '\n\n Press space to finish'];

    %show text
    DrawFormattedText(windowP, workupInstructs, 'center', 'center', [1 1 1]);
    DrawFormattedText(windowC, workupInstructs, 'center', 'center', [1 1 1]);
    Screen('Flip', windowP);
    Screen('Flip', windowC);



    %response = []; %initialise
    while true % Infinite loop until 'space' is pressed
        [keyIsDown, ~, keyCode] = KbCheck;
        if keyIsDown
            if keyCode(KbName('ESCAPE'))
                sca; % Exit the experiment
                return;

            elseif keyCode(KbName(keyToShockParticipant)) & digitimerConnected
                % If participant shock key is pressed (and digitimer is
                % connected), send shock to participant
                disp([upper(keyToShockParticipant) ' key pressed']);
                WaitSecs(0.001); % Wait X seconds to stop it logging key press as multiple key presses
                sendShock(byteParticipant, pinNoParticipant, nreps, adress, ioObj, status, mark.shockPworkup, serialPort, waitTimeBetweenShocks)

            elseif keyCode(KbName(keyToShockCompanion)) & digitimerConnected
                % If companion shock key is pressed (and digitimer is
                % connected), send shock to companion
                disp([upper(keyToShockCompanion) ' key pressed']);
                WaitSecs(0.001); % Wait X seconds to stop it logging key press as multiple key presses
                sendShock(byteCompanion, pinNoCompanion, nreps, adress, ioObj, status, mark.shockCworkup, serialPort, waitTimeBetweenShocks)

            elseif keyCode(KbName('space'))
                %response = 'space';
                while keyIsDown % Wait until spacebar is released
                    [keyIsDown, ~, ~] = KbCheck;
                    WaitSecs(0.001); % Wait X seconds to make sure key has been released
                end
                break; % Break out of the loop when 'space' is pressed
            end
        end
    end

    %close psychtoolbox window so we can enter user ratings in gui
    sca

    %% Ask for participant and companion intensity ranges in pop up gui

    validInput = false;

    while validInput == false
        promptAll = {[nameParticipant ' min intensity'], [nameParticipant ' max intensity'], ... %set prompts for the gui
            [nameCompanion ' min intensity'], [nameCompanion ' max intensity']};
        dlgtitleAll = 'Enter Intensity Ranges';
        dimsAll = [1 100]; % Set the width of the input fields
        definputAll = {'', '', '', '', '', ''}; % Default values

        allValues = inputdlg(promptAll, dlgtitleAll, dimsAll, definputAll); %display gui and get user input

        % Check if the user clicked 'Cancel'
        if isempty(allValues)
            disp('User cancelled');
            return; % or exit the script
        end

        % Access values as a cell array
        lowIntensityP = str2double(allValues{1});
        highIntensityP = str2double(allValues{2});
        lowIntensityC = str2double(allValues{3});
        highIntensityC = str2double(allValues{4});

        % Check if valid numeric values were entered (numeric, in range
        % 0.1-100, min < max)
        if isnan(lowIntensityP) || isnan(highIntensityP) || isnan(lowIntensityC) || isnan(highIntensityC) || ...
                lowIntensityP <= 0 || lowIntensityP > 100 || ...
                highIntensityP <= 0 || highIntensityP > 100 || ...
                lowIntensityC <= 0 || lowIntensityC > 100 || ...
                highIntensityC <= 0 || highIntensityC > 100 || ...
                lowIntensityP >= highIntensityP || ...
                lowIntensityC >= highIntensityC
            disp('Invalid input. Please enter numeric values in range 0-100.');

        else
            %if input is acceptable then break out of loop
            validInput = true;

        end
    end

    %% open psychtoolbox window
    [windowP, windowRectP] = PsychImaging('OpenWindow', screenNumber1, [0 0 0]);
    [windowC, windowRectC] = PsychImaging('OpenWindow', screenNumber2, [0 0 0]);

    %set font size
    Screen('TextSize', windowP, textSizeMed);
    Screen('TextSize', windowC, textSizeMed);

    %% Load images for shocks
    highShockImg = imread(highShockImgFile); %high shock image
    lowShockImg = imread(lowShockImgFile); %low shock image
    safeShockImg = imread(safeShockImgFile); %no shock image

    %make into textures
    highShockImgTex = Screen('MakeTexture', windowP, highShockImg); %texture for high shock image
    lowShockImgTex = Screen('MakeTexture', windowP, lowShockImg); %texture for low shock image
    safeShockImgTex = Screen('MakeTexture', windowP, safeShockImg); %texture for no shock image

    % Get the size of the image
    imageSize = size(highShockImg);
    imageWidth = imageSize(2);
    imageHeight = imageSize(1);

    % Define the destination rectangle for the image
    shockImgCentreXY = [windowRectP(3)*0.5 windowRectP(4)*0.75];

    shockImgRectWidth = windowRectP(3)*0.24;
    shockImgRectHeight = shockImgRectWidth * (imageHeight/imageWidth);

    shockImgRect = [shockImgCentreXY(1) - 0.5*shockImgRectWidth, shockImgCentreXY(2) - 0.5*shockImgRectHeight,...
        shockImgCentreXY(1) + 0.5*shockImgRectWidth, shockImgCentreXY(2) + 0.5*shockImgRectHeight];

    %define shock text position
    shockMessageRect = [startBoxRect(1), startBoxRect(2) - 0.2*windowRectP(4), startBoxRect(3), startBoxRect(4) - 0.2*windowRectP(4)];


    %% Instructions

    instructionsText = ['On each turn, one of you will receive an electric shock.\n\n'...
        'There are 3 levels of shock intensity: high, low and safe (no shock).\n\n'...
        'You will receive up to ' num2str(nTrialsPerCondPerP(1) + nTrialsPerCondPerP(2) +2) ' shocks each.\n\n'... %tell participants they will receive two more shocks than they actually will so they will not know they are safe in final trial of the task
        'You can be shocked up to 5 turns in a row.\n\n'...
        'On some turns, you will be asked to rate on your tablet how receiving the shock \n' ...
        'or watching your friend receive the shock made you feel.'];

    %draw text and button - screen 1
    DrawFormattedText(windowP, instructionsText, 'center', 'center', white, [], [], [], [], [], startBoxRect); %draw button text
    DrawFormattedText(windowP, 'Press space to continue', 'center', 'center', white, [], [], [], [], [], lowerButtonRect); %draw button text
    %draw text and button - screen 2
    DrawFormattedText(windowC, instructionsText, 'center', 'center', white, [], [], [], [], [], startBoxRect*window2scalingFactor); %draw button text
    DrawFormattedText(windowC, 'Press space to continue', 'center', 'center', white, [], [], [], [], [], lowerButtonRect*window2scalingFactor); %draw button text

    %flip screens
    Screen('Flip', windowP);
    Screen('Flip', windowC);

    %listen for spacebar presses
    pressSpaceContinue();

    WaitSecs(1); %wait x seconds before showing next screen

    %% Preallocate data table
    fulldataP = predefineDataTable(0);
    fulldataC = predefineDataTable(0);

    %% Loop for running through triaks of task
    trialCounter = 0; %initialise trialCounter at zero
    trialCounterX = 50; %define x position of trial counter
    trialCounterY = 50; %define y position of trial counter

    for i_block = 1 : nBlocks

        % Send textmark for start of block
        if sendTextMarks == true
            write(serialPort, mark.blockStart, "string"); %send textmark for start of block
        end

        %get observer condition
        observerCondThisBlock = observerCondsPerBlock{i_block};

        % Calculate the range of rows to read for the current block
        startRow = (i_block - 1) * nTrialsPerBlock + 1;
        endRow = i_block * nTrialsPerBlock;

        % Ensure that endRow does not exceed the total number of rows
        endRow = min(endRow, size(trialOrderTable, 1));

        % Read the specified range of rows from the table
        currentBlockTable = trialOrderTable(startRow:endRow, :);


        %----------block start message-----------

        %set message depending on intensity should be hidden or visible to
        %observer
        if strcmp(observerCondThisBlock, "intensityhidden")
            text = ['In this round, only the shock recipient will be told the shock intensity']; %define message text
        elseif strcmp(observerCondThisBlock, "intensityvisible")
            text = ['In this round, both people will be told the shock intensity']; %define message text
        end

        %draw text and button - screen 1
        DrawFormattedText(windowP, text, 'center', 'center', white, [], [], [], [], [], startBoxRect); %draw button text
        DrawFormattedText(windowP, 'Press space to start', 'center', 'center', white, [], [], [], [], [], lowerButtonRect); %draw button text
        %draw text and button - screen 2
        DrawFormattedText(windowC, text, 'center', 'center', white, [], [], [], [], [], startBoxRect*window2scalingFactor); %draw button text
        DrawFormattedText(windowC, 'Press space to start', 'center', 'center', white, [], [], [], [], [], lowerButtonRect*window2scalingFactor); %draw button text

        %flip screens
        Screen('Flip', windowP);
        Screen('Flip', windowC);

        %listen for spacebar presses
        pressSpaceContinue();

        WaitSecs(1); %wait x seconds before showing next screen


        % Loop through trials in the current block
        for i_trial_per_block = 1:size(currentBlockTable, 1)

            % Increment the trial counter
            trialCounter = trialCounter + 1;
            counterText = sprintf('Turn: %d', trialCounter); %define trial counter text

            % Initiate faulty shock boolean to false
            shockFaulty = false;

            %predefine data table, one for each subject
            trialDataP = predefineDataTable(1);
            trialDataC = predefineDataTable(1);

            %hide mouse to we don't see loading cursor
            HideCursor(windowP);
            HideCursor(windowC);

            % Access the current trial condition from the currentBlockTable
            if ismember(currentBlockTable{i_trial_per_block, "Participant"}, shockConds)
                %if participant is to be shocked/safe
                shockRecipientName = nameParticipant;
                shockRecipient = 'Participant';
                shockStrength = currentBlockTable{i_trial_per_block, "Participant"}; %get shock intensity from conditions table
                %windowRecipient = windowP; %set window so participant sees intensity in intensityhidden blocks
                %windowObserver = windowC;%set window so companion doesn't see intensity in intensityhidden blocks

            elseif ismember(currentBlockTable{i_trial_per_block, "Companion"}, shockConds)
                %if companion is to be shocked/safe
                shockRecipientName = nameCompanion;
                shockRecipient = 'Companion';
                shockStrength = currentBlockTable{i_trial_per_block, "Companion"};
                %windowRecipient = windowC; %set window so companion sees intensity in intensityhidden blocks
                %windowObserver = windowP;%set window so participant doesn't see intensity in intensityhidden blocks
            end

            %define shock image for this trial
            if strcmpi(shockStrength, 'high')
                shockImgTex = highShockImgTex;
            elseif strcmpi(shockStrength, 'low')
                shockImgTex = lowShockImgTex;
            elseif strcmpi(shockStrength, 'safe')
                shockImgTex = safeShockImgTex;
            end

            %define textmark for this trial
            if strcmp(shockRecipient, 'Participant') && strcmp(shockStrength, 'high') && sendTextMarks == true
                textMarkShockCond = mark.shockPhigh;
            elseif strcmp(shockRecipient, 'Participant') && strcmp(shockStrength, 'low') && sendTextMarks == true
                textMarkShockCond = mark.shockPlow;
            elseif strcmp(shockRecipient, 'Participant') && strcmp(shockStrength, 'safe') && sendTextMarks == true
                textMarkShockCond = mark.shockPsafe;
            elseif strcmp(shockRecipient, 'Companion') && strcmp(shockStrength, 'high') && sendTextMarks == true
                textMarkShockCond = mark.shockChigh;
            elseif strcmp(shockRecipient, 'Companion') && strcmp(shockStrength, 'low') && sendTextMarks == true
                textMarkShockCond = mark.shockClow;
            elseif strcmp(shockRecipient, 'Companion') && strcmp(shockStrength, 'safe') && sendTextMarks == true
                textMarkShockCond = mark.shockCsafe;
            else
                textMarkShockCond = []; %if not sending textmarks then set to blank
            end

            % ----- Show 'Person to be shocked is...' message (always on both screens) ----------

            %Draw text - screen 1
            Screen('TextSize', windowP, textSizeMed);
            DrawFormattedText(windowP, 'Person to be shocked is...' , 'center', 'center', white, [], [], [], [], [], shockMessageRect); %draw text
            %DrawFormattedText(windowP, counterText, trialCounterX, trialCounterY, white); % Display the trial counter
            %Draw text - screen 2
            Screen('TextSize', windowP, textSizeMed);
            DrawFormattedText(windowC, 'Person to be shocked is...' , 'center', 'center', white, [], [], [], [], [], shockMessageRect * window2scalingFactor); %draw text
            %DrawFormattedText(windowC, counterText, trialCounterX, trialCounterY, white);

            %send textmark
            if sendTextMarks == true
                write(serialPort, mark.antPreName, "string");
            end

            %flip screens
            Screen('Flip', windowP);
            Screen('Flip', windowC);

            % Wait X seconds
            WaitSecs(durationAnticipationPreName)


            % ----- Show name of person to be shocked ---------
            %Draw name text - screen 1 (same on both screens)
            Screen('TextSize', windowP, textSizeMed);
            DrawFormattedText(windowP, 'Person to be shocked is...' , 'center', 'center', white, [], [], [], [], [], shockMessageRect); %draw text
            %DrawFormattedText(windowP, counterText, trialCounterX, trialCounterY, white);
            Screen('TextSize', windowP, textSizeBig);
            DrawFormattedText(windowP, shockRecipientName, 'center', 'center', white, [], [], [], [], [], startBoxRect); %draw text

            %Draw name text - screen 2 (same on both screens)
            Screen('TextSize', windowC, textSizeMed);
            DrawFormattedText(windowC, 'Person to be shocked is...' , 'center', 'center', white, [], [], [], [], [], shockMessageRect * window2scalingFactor); %draw text
            %DrawFormattedText(windowC, counterText, trialCounterX, trialCounterY, white);
            Screen('TextSize', windowC, textSizeBig);
            DrawFormattedText(windowC, shockRecipientName, 'center', 'center', white, [], [], [], [], [], startBoxRect * window2scalingFactor); %draw text

            %Draw shock intensity image
            if strcmp(observerCondThisBlock, "intensityvisible")
                %if shock intensity should be visible to observer in this
                %block, draw image on both screens
                Screen('DrawTexture', windowP, shockImgTex, [], shockImgRect); %draw shock image
                Screen('DrawTexture', windowC, shockImgTex, [], shockImgRect * window2scalingFactor); %draw shock image

            elseif strcmp(observerCondThisBlock, "intensityhidden") && strcmp(shockRecipient, "Participant")
                %if shock intensity should not be visible to observer, and
                %participant is receiving shock, only show on participant's
                %screen
                Screen('DrawTexture', windowP, shockImgTex, [], shockImgRect ); %draw shock image

            elseif strcmp(observerCondThisBlock, "intensityhidden") && strcmp(shockRecipient, "Companion")
                %if shock intensity should not be visible to observer, and
                %participant is receiving shock, only show on participant's
                %screen
                Screen('DrawTexture', windowC, shockImgTex, [], shockImgRect * window2scalingFactor); %draw shock image

            end


            %send textmark
            if sendTextMarks == true
                write(serialPort, mark.antPostName, "string");
            end

            %flip windows
            Screen('Flip', windowP);
            Screen('Flip', windowC);

            %wait jittered duration
            jitter = rand() * (durationAnticipationPostName(2) - durationAnticipationPostName(1));
            WaitSecs(durationAnticipationPostName(1) + jitter);


            % ----- Deliver shock -------------------
            %show shock message
            %If digitimer is connected then deliver shock
            if digitimerConnected && strcmpi(shockRecipient, "Participant") && ~strcmpi(shockStrength, "safe")
                % if shock recipient if participant then shock participant
                sendShock(byteParticipant, pinNoParticipant, nreps, adress, ioObj, status, textMarkShockCond, serialPort, waitTimeBetweenShocks)

            elseif digitimerConnected && strcmpi(shockRecipient, "Companion") && ~strcmpi(shockStrength, "safe")
                % if shock recipient if companion then shock companion
                sendShock(byteCompanion, pinNoCompanion, nreps, adress, ioObj, status, textMarkShockCond, serialPort, waitTimeBetweenShocks)

            elseif strcmpi(shockStrength, "safe")
                %if condition is safe then wait shock duration
                WaitSecs( (waitTimeBetweenShocks * nreps) + (0.001 * nreps));
            end


            % ----- Response period -------------------
            %Draw trial counter
            Screen('TextSize', windowP, textSizeMed);
            Screen('TextSize', windowC, textSizeMed);
            %DrawFormattedText(windowP, counterText, trialCounterX, trialCounterY, white);
            %DrawFormattedText(windowC, counterText, trialCounterX, trialCounterY, white);

            %send textmark
            if sendTextMarks == true
                write(serialPort, mark.responsePeriod, "string");
            end

            % Flip screens
            Screen('Flip', windowP);
            Screen('Flip', windowC);

            %Wait X seconds
            WaitSecs(durationResponse)


            % ----- Show 'rate your response' message  ----------
            %play tone so participants know to submit response
            sound(tone, fs);

            if i_trial_per_block <= size(currentBlockTable, 1)

                if ismember(trialCounter, idxRatingTrials)
                    text = ['\nSUBMIT RATINGS ON YOUR TABLET!' ...
                        '\n \n Experimenter set next shock settings'...
                        '\n \n Press space to continue']; %define message text
                else
                    text = ['\nExperimenter set next shock settings.' ...
                        '\n \n Press space to continue']; %define message text
                end
                %draw text - screen 1
                Screen('TextSize', windowP, textSizeMed);
                DrawFormattedText(windowP, text, 'center', 'center', white, [], [], [], [], [], startBoxRect); %draw text
                DrawFormattedText(windowP, counterText, trialCounterX, trialCounterY, white);

                %draw text - screen 2
                Screen('TextSize', windowC, textSizeMed);
                DrawFormattedText(windowC, text, 'center', 'center', white, [], [], [], [], [], startBoxRect*window2scalingFactor); %draw text
                DrawFormattedText(windowC, counterText, trialCounterX, trialCounterY, white);

                %send textmark
                if sendTextMarks == true
                    write(serialPort, mark.submitRatings, "string");
                end

                %flip screens
                Screen('Flip', windowP);
                Screen('Flip', windowC);

                % ----- Log shock data  ----------
                %log trial/block number
                trialDataP.sujectID = participantID;
                trialDataC.sujectID = companionID;
                trialDataP.blockNo = i_block; %block number
                trialDataC.blockNo = i_block; %block number
                trialDataP.trialNoBlock = i_trial_per_block; %trial number within block
                trialDataC.trialNoBlock = i_trial_per_block; %trial number within block
                trialDataP.trialNo = (i_block-1)*nTrialsPerBlock + i_trial_per_block; %trial number overall
                trialDataC.trialNo = (i_block-1)*nTrialsPerBlock + i_trial_per_block; %trial number overall

                % log observer condition
                trialDataP.observerCond = observerCondThisBlock;
                trialDataC.observerCond = observerCondThisBlock;


                % log shock recipient
                if strcmp(shockRecipient, "Participant")
                    trialDataP.shockRecipient = 'self';
                    trialDataC.shockRecipient = 'other';
                elseif strcmp(shockRecipient, "Companion")
                    trialDataP.shockRecipient = 'other';
                    trialDataC.shockRecipient = 'self';
                end

                % log shock intensity
                if strcmpi(shockStrength, 'high')
                    trialDataP.shockIntensity = 'high';
                    trialDataC.shockIntensity = 'high';
                elseif strcmpi(shockStrength, 'low')
                    trialDataP.shockIntensity = 'low';
                    trialDataC.shockIntensity = 'low';
                elseif strcmpi(shockStrength, 'safe')
                    trialDataP.shockIntensity = 'safe';
                    trialDataC.shockIntensity = 'safe';
                end

                %add timestamp
                dateTimestamp = datenum(datetime(datetime, 'InputFormat', 'yyyy-MM-dd HH:mm:ss.SSS')); %convert back to datetime using datetime(dateTimeMs, 'Format', 'yyyy-MM-dd HH:mm:ss.SSS', 'ConvertFrom', 'datenum')
                trialDataP.timestamp = dateTimestamp;
                trialDataC.timestamp = dateTimestamp;

                %add whether subjects submitted a rating on this trial
                if ismember(trialCounter, idxRatingTrials)
                    trialDataP.ratingSubmitted = "yes";
                    trialDataC.ratingSubmitted = "yes";
                else
                    trialDataP.ratingSubmitted = "no";
                    trialDataC.ratingSubmitted = "no";
                end

                % Add min and max shock intensity for participant and companion trialData
                trialDataP.lowIntensitySelf = lowIntensityP;
                trialDataP.highIntensitySelf = highIntensityP;
                trialDataP.lowIntensityOther = lowIntensityC;
                trialDataP.highIntensityOther = highIntensityC;

                trialDataC.lowIntensitySelf = lowIntensityC;
                trialDataC.highIntensitySelf = highIntensityC;
                trialDataC.lowIntensityOther = lowIntensityP;
                trialDataC.highIntensityOther = highIntensityP;


                %add shock data for this trial to main table
                fulldataP = [fulldataP; trialDataP];
                fulldataC = [fulldataC; trialDataC];
                fulldataBoth = [fulldataP; fulldataC];

                % save data after every trial in case task crashes
                saveFileName = [taskFolder '/' 'Task shock data' '/' companionID(1:length(companionID)-1) '_empathy.csv'];
                writetable(fulldataBoth, saveFileName);

                %-----Listen for key press to continue
                response = [];
                while isempty(response)
                    [keyIsDown, ~, keyCode] = KbCheck;
                    if keyIsDown
                        if keyCode(KbName('ESCAPE'))
                            sca; % Exit the experiment
                            return;

                        elseif keyCode(KbName('e'))
                            %if experimenter presses 'e', log that shock was faulty
                            while keyIsDown % Wait until 'e' is released
                                [keyIsDown, ~, ~] = KbCheck;
                                WaitSecs(0.001); % Wait X seconds just to make sure key was released
                            end

                            %update faultyShock variable
                            fulldataP.faultyShock(end) = 1;
                            fulldataC.faultyShock(end) = 1;

                            %resave data
                            fulldataBoth = [fulldataP; fulldataC];
                            writetable(fulldataBoth, saveFileName);

                            %Redraw text in red to indicate error logged
                            red = [1 0 0];
                            Screen('TextSize', windowP, textSizeMed);
                            DrawFormattedText(windowP, text, 'center', 'center', red, [], [], [], [], [], startBoxRect); %draw text
                            DrawFormattedText(windowP, counterText, trialCounterX, trialCounterY, red);
                            
                            Screen('TextSize', windowC, textSizeMed);
                            DrawFormattedText(windowC, text, 'center', 'center', red, [], [], [], [], [], startBoxRect*window2scalingFactor); %draw text
                            DrawFormattedText(windowC, counterText, trialCounterX, trialCounterY, red);
                            
                            Screen('Flip', windowP);
                            Screen('Flip', windowC);
                            

                            % Continue the loop to keep checking for other key presses
                            continue;

                        elseif keyCode(KbName('space'))
                            %Press space to proceed
                            response = 'space';
                            while keyIsDown % Wait until spacebar is released
                                [keyIsDown, ~, ~] = KbCheck;
                                WaitSecs(0.001); % Wait X seconds just to make sure key was released
                            end
                        end
                    end
                end

            end

            %send textmark for end of trial
            if sendTextMarks == true
                write(serialPort, mark.endTrial, "string"); %send textmark for end of trial
            end

        end; clear i_trial_per_block

        %after certain blocks, show message for participants to take a break
        if ismember(i_block, iblocksWithRatings)

            %show mouse again
            ShowCursor('Arrow', windowP);
            ShowCursor('Arrow', windowC);

            %set text
            text = ['\nTime for a break!' ...
                '\n \n Press space to resume']; %define message text

            %draw time for a break message
            DrawFormattedText(windowP, text, 'center', 'center', white, [], [], [], [], [], startBoxRect);
            DrawFormattedText(windowC, text, 'center', 'center', white, [], [], [], [], [], startBoxRect * window2scalingFactor);

            %flip windows
            Screen('Flip', windowP);
            Screen('Flip', windowC);

            %listen for key presses
            response = [];
            while isempty(response)
                [keyIsDown, ~, keyCode] = KbCheck;
                if keyIsDown
                    if keyCode(KbName('ESCAPE'))
                        sca; % Exit the experiment
                        return;
                    elseif keyCode(KbName('space'))
                        response = 'space';
                        while keyIsDown % Wait until spacebar is released
                            [keyIsDown, ~, ~] = KbCheck;
                            WaitSecs(0.001); % Wait X seconds just to make sure key was released
                        end
                    end
                end
            end

        end

    end; clear i_block

    %show mouse again
    ShowCursor('Arrow', windowP);
    ShowCursor('Arrow', windowC);


    %% Show task complete

    % Start the task
    if sendTextMarks == true
        write(serialPort, mark.taskEnd, "string"); %send textmark for end of task
    end

    %show task completed message
    text = 'Task completed! \n Well done! \n Press space to end.';

    %draw time for a break message
    DrawFormattedText(windowP, text, 'center', 'center', white, [], [], [], [], [], startBoxRect);
    DrawFormattedText(windowC, text, 'center', 'center', white, [], [], [], [], [], startBoxRect * window2scalingFactor);

    %flip windows
    Screen('Flip', windowP);
    Screen('Flip', windowC);

    %listen for key presses
    response = [];
    while isempty(response)
        [keyIsDown, ~, keyCode] = KbCheck;
        if keyIsDown
            if keyCode(KbName('ESCAPE'))
                sca; % Exit the experiment
                return;
            elseif keyCode(KbName('space'))
                response = 'space';
                while keyIsDown % Wait until spacebar is released
                    [keyIsDown, ~, ~] = KbCheck;
                    WaitSecs(0.001); % Wait X seconds just to make sure key was released
                end
            end
        end
    end

    %close
    sca;

catch exception
    disp(['Error: ' exception.message]);
    sca;
    rethrow(exception);

end
end

%% Function predefine data table
function dataTable = predefineDataTable(numTrials)
dataTable = table(...
    cell(numTrials, 1), ...  % String column (subjectID)
    NaN(numTrials, 1), ...  % Numeric column (Timestamp)
    NaN(numTrials, 1), ...  % Numeric column (BlockNo)
    NaN(numTrials, 1), ...  % Numeric column (TrialNo)
    NaN(numTrials, 1), ...  % Numeric column (TrialNoBlock)
    cell(numTrials, 1), ...  % String column (observerCond)
    cell(numTrials, 1), ...  % String column (shockRecipient)
    cell(numTrials, 1), ...  % String column (ShockIntensity)
    NaN(numTrials, 1), ...  % NaN column (low shock intensity - self)
    NaN(numTrials, 1), ...  % NaN column (high shock intensity - self)
    NaN(numTrials, 1), ...  % NaN column (low shock intensity - other)
    NaN(numTrials, 1), ...  % NaN column (high shock intensity - other)
    cell(numTrials, 1), ...  % String column (rating submitted)
    zeros(numTrials, 1), ...  % Zeros column (faultyShock boolean)
    'VariableNames', {'sujectID', 'timestamp', 'blockNo', 'trialNo', 'trialNoBlock', ...
    'observerCond', 'shockRecipient', ...
    'shockIntensity', 'lowIntensitySelf', 'highIntensitySelf', ...
    'lowIntensityOther', 'highIntensityOther', ...
    'ratingSubmitted', 'faultyShock'});
end


%% function press spacebar
function pressSpaceContinue()
response = [];
while isempty(response)
    [keyIsDown, ~, keyCode] = KbCheck;
    if keyIsDown
        if keyCode(KbName('ESCAPE'))
            sca; % Exit the experiment
            return;
        elseif keyCode(KbName('space'))
            response = 'space';
            while keyIsDown % Wait until spacebar is released
                [keyIsDown, ~, ~] = KbCheck;
                WaitSecs(0.001); % Wait X seconds just to make sure key was released
            end
        end
    end
end
end

%% Function for sending shock to a specific Digitimer DS7 via the parallel port

function sendShock(byte, pinNumber, nreps, adress, ioObj, status, textMark, serialPort, pauseBetweenShocks)

% initialize access to the inpoutx64 low-level I/O driver
config_io;
outp(adress, byte);

if ~isempty(serialPort)
    write(serialPort, textMark, "string"); %send textmark for shock onset
end

%Loop to send chain of pulses (n = nreps)
for i = 1:nreps
    data_out = 1;
    io64(ioObj, adress, bitset(0, pinNumber, data_out)); %send square wave (1s) out of parallel port
    io64(ioObj, adress, bitset(0, pinNumber, 0));  %stop sending square wave (send zero)
    pause(pauseBetweenShocks); %pause X seconds
end

end



