function varargout = plexme(varargin)
% PLEXME MATLAB code for plexme.fig
%      PLEXME, by itself, creates a new PLEXME or raises the existing
%      singleton*.
%
%      H = PLEXME returns the handle to a new PLEXME or the handle to
%      the existing singleton*.
%
%      PLEXME('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in PLEXME.M with the given input arguments.
%
%      PLEXME('Property','Value',...) creates a new PLEXME or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before plexme_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to plexme_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help plexme

% Last Modified by GUIDE v2.5 12-May-2015 17:29:04

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @plexme_OpeningFcn, ...
                   'gui_OutputFcn',  @plexme_OutputFcn, ...
                   'gui_LayoutFcn',  [] , ...
                   'gui_Callback',   []);
if nargin && ischar(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end
% End initialization code - DO NOT EDIT




function [ intan_pin] = map_plexon_pin_to_intan(plexon_pin)
intan_pin = handles.PIN_NAMES(2, find(handles.PIN_NAMES(1,:) == plexon_pin));


function [ plexon_pin] = map_intan_pin_to_plexon(intan_pin)
plexon_pin = handles.PIN_NAMES(1, find(handles.PIN_NAMES(2,:) == intan_pin));



% --- Executes just before plexme is made visible.
function plexme_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to plexme (see VARARGIN)


% Choose default command line output for plexme
handles.output = hObject;

handles.START_uAMPS = 4;
handles.MAX_uAMPS = 50;
handles.INCREASE_STEP = 1.05;
handles.HALF_TIME_uS = 400;
handles.INTERSPIKE_S = 0.5;
handles.VoltageLimit = 3;
handles.valid = zeros(1, 16);
handles.monitor_electrode = 1;
handles.stim = zeros(1, 16);  % Stimulate these electrodes
handles.timer = [];
handles.box = 1;   % Assume (hardcode) 1 Plexon box
handles.open = false;
handles.running = false;

% NI control rubbish
handles.NIsession = [];

global CURRENT_uAMPS;
CURRENT_uAMPS = handles.START_uAMPS;
global change;
change = handles.INCREASE_STEP;
global NEGFIRST;
NEGFIRST = false;


% Top row is the names of pins on the Plexon.  Bottom row is corresponding
% pins on the Intan.
handles.PIN_NAMES = [ 1  2  3  4  5  6  7  8  9  10  11  12  13  14  15  16 ; ...
                      0  0  0  0  0  0  0  0  0   0   0   0   0   0   0   0 ];


set(handles.startcurrent, 'String', sprintf('%d', round(handles.START_uAMPS)));
set(handles.currentcurrent, 'String', sprintf('%.2g', CURRENT_uAMPS));
set(handles.maxcurrent, 'String', sprintf('%d', round(handles.MAX_uAMPS)));
set(handles.increasefactor, 'String', sprintf('%g', handles.INCREASE_STEP));
set(handles.halftime, 'String', sprintf('%d', round(handles.HALF_TIME_uS)));
set(handles.delaytime, 'String', sprintf('%g', handles.INTERSPIKE_S));
set(handles.negativefirst, 'Value', NEGFIRST);
newvals = {};
for i = 1:16
    newvals{end+1} = sprintf('%d', i);
end
set(handles.monitor_electrode_control, 'String', newvals);
% Also make sure that the monitor spinbox is the right colour


handles.disable_on_run = { handles.currentcurrent, handles.startcurrent, ...
        handles.maxcurrent, handles.increasefactor, handles.halftime, handles.delaytime};
for i = 1:16
        cmd = sprintf('handles.disable_on_run{end+1} = handles.electrode%d;', i);
        eval(cmd);
        cmd = sprintf('handles.disable_on_run{end+1} = handles.stim%d;', i);
        eval(cmd);
end

for i = 1:16
        cmd = sprintf('set(handles.electrode%d, ''Value'', 0);', i);
        eval(cmd);
        cmd = sprintf('set(handles.stim%d, ''Enable'', ''off'');', i);
        eval(cmd);
        cmd = sprintf('set(handles.stim%d, ''Value'', false);', i);
        eval(cmd);
end

% Open the stimulator

err = PS_InitAllStim;
switch err
    case 1
        msgbox({'Error: Could not open the Plexon box.', ' ', 'POSSIBLE CAUSES:', '* Device is not attached', '* Device is not turned on', '* Another program is using the device', ...
            '* Device needs rebooting', '', 'TO REBOOT:', '1. DISCONNECT THE BIRD!!!', '2. Power cycle', '3. Reconnect bird.'});
db        error('plexon:init', 'Plexon initialisation error: %s', PS_GetExtendedErrorInfo(err));
    case 2
        msgbox({'Error: Could not open the Plexon box.', ' ', 'POSSIBLE CAUSES:', '* Device is not attached', '* Device is not turned on', '* Another program is using the device', ...
            '* Device needs rebooting', '', 'TO REBOOT:', '1. DISCONNECT THE BIRD!!!', '2. Power cycle', '3. Reconnect bird.'});

        error('plexon:init', 'Plexon: no devices available.  Is the blue box on?  Is other software accessing it?');
    otherwise
        handles.open = true;
end

try
    [nchan, err] = PS_GetNChannels(handles.box);
    if err
        ME = MException('plexon:init', 'Plexon: invalid stimulator number "%d".', handles.box);
        throw(ME);
    else
        disp(sprintf('Plexon device %d has %d channels.', handles.box, nchan));
    end
    if nchan ~= 16
        ME = MException('plexon:init', 'Ben assumed that there would always be 16 channels, but there are in fact %d', nchan);
        throw(ME);
    end


    err = PS_SetTriggerMode(handles.box, 0);
    if err
        ME = MException('plexon:stimulate', 'Could not set trigger mode on stimbox %d', handles.box);
        throw(ME);
    end

catch ME
    disp(sprintf('Caught initialisation error %s (%s).  Shutting down...', ME.identifier, ME.message));
    report = getReport(ME);
    stop_Callback(hObject, event, handles);
    err = PS_CloseAllStim;
    handles.open = false;
    rethrow(ME);
end

set(hObject, 'CloseRequestFcn', {@gui_close_callback, handles});
              


%% Open NI acquisition board
dev='Dev1'; % location of input device
channels = 0:1;
channel_labels = {'Voltage', 'Current', 'error23842'}; % labels for INCHANNELS
daq.reset;
handles.NIsession = daq.createSession('ni');
handles.NIsession.Rate = 100000;
handles.NIsession.IsContinuous = 0;
handles.NIsession.DurationInSeconds = 0.007;

for i = 1:length(channels)
    addAnalogInputChannel(handles.NIsession, dev, sprintf('ai%d', channels(i)), 'voltage');
    param_names = fieldnames(handles.NIsession.Channels(i));
	handles.NIsession.Channels(i).Name = channel_labels{i};
	handles.NIsession.Channels(i).Coupling = 'DC';
 	if any(strcmp(param_names,'TerminalConfig'))
 		handles.NIsession.Channels(i).TerminalConfig='SingleEnded';
 	elseif any(strcmp(param_names,'InputType'))
 		handles.NIsession.Channels(i).InputType='SingleEnded';
 	else
 		error('Could not set NiDaq input type');
    end
end
handles.NI.listeners{1}=addlistener(handles.NIsession, 'DataAvailable',...
	@(obj,event) NIsession_callback(obj,event));
handles.NIsession.NotifyWhenDataAvailableExceeds=round(handles.NIsession.Rate*handles.NIsession.DurationInSeconds);
prepare(handles.NIsession);





guidata(hObject, handles);




function NIsession_callback(obj, event)
global VOLTAGE_RANGE_LAST_STIM;
figure(2);
plot(event.Data);
legend(obj.Channels.Name);
VOLTAGE_RANGE_LAST_STIM = [ max(event.Data(:,1)) min(event.Data(:,1))];



function gui_close_callback(hObject, callbackdata, handles)
disp('Shutting down...');
if handles.running
    stop(handles.timer); % This stops stimulation as well
    delete(handles.timer);
end
if ~isempty(handles.NIsession)
    % Stop NI session?!!?
    stop(handles.NIsession);
    release(handles.NIsession);
    handles.NIsession = [];
end
if handles.open
    err = PS_CloseAllStim;
    if err
        msgbox({'ERROR CLOSING STIMULATOR', 'Could not contact Plexon stimulator for shutdown!'});
    end
else
     msgbox({'ERROR CLOSING STIMULATOR', 'Could not contact Plexon stimulator for shutdown!'});
end
delete(hObject);


% UIWAIT makes plexme wait for user response (see UIRESUME)
% uiwait(handles.figure1);


% --- Outputs from this function are returned to the command line.
function varargout = plexme_OutputFcn(hObject, eventdata, handles) 
varargout{1} = handles.output;




% --- Executes on button press in negativefirst.
function negativefirst_Callback(hObject, eventdata, handles)
global NEGFIRST;
NEGFIRST = get(hObject, 'Value');
global CURRENT_uAMPS;
CURRENT_uAMPS = handles.START_uAMPS;
set(handles.currentcurrent, 'String', sprintf('%.2g', CURRENT_uAMPS));
guidata(hObject, handles);



function startcurrent_Callback(hObject, eventdata, handles)
handles.START_uAMPS = str2double(get(hObject,'String'));
guidata(hObject, handles);


% --- Executes during object creation, after setting all properties.
function startcurrent_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function maxcurrent_Callback(hObject, eventdata, handles)
handles.MAX_uAMPS = str2double(get(hObject,'String'));
guidata(hObject, handles);


% --- Executes during object creation, after setting all properties.
function maxcurrent_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end




function increasefactor_Callback(hObject, eventdata, handles)
handles.INCREASE_STEP = str2double(get(hObject,'String'));
guidata(hObject, handles);


% --- Executes during object creation, after setting all properties.
function increasefactor_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function halftime_Callback(hObject, eventdata, handles)
handles.HALF_TIME_uS = str2double(get(hObject,'String'));
guidata(hObject, handles);


% --- Executes during object creation, after setting all properties.
function halftime_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function delaytime_Callback(hObject, eventdata, handles)
handles.INTERSPIKE_S = str2double(get(hObject,'String'));
guidata(hObject, handles);


% --- Executes during object creation, after setting all properties.
function delaytime_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


function electrode_universal_callback(hObject, eventdata, handles)
whichone = str2num(hObject.String);
value = get(hObject, 'Value');
handles.valid(whichone) = value;
if handles.valid(whichone)
        newstate = 'on';
else
        newstate = 'off';
end
% "stimulate this electrode" should be enabled or disabled according to the
% state of this button
cmd = sprintf('set(handles.stim%d, ''Enable'', ''%s'');', whichone, newstate);
eval(cmd);
% "stimulate this electrode" should default to 0...
cmd = sprintf('set(handles.stim%d, ''Value'', 0);', whichone);
eval(cmd);
handles.stim(whichone) = 0;
if 0 % This was for when stimAll was a persistent variable.
    % ...unless...
    if handles.stimAll
        % Set the "stimulate this electrode" value to match
        cmd = sprintf('prev = get(handles.stim%d, ''Value'');', whichone);
        eval(cmd);
        cmd = sprintf('set(handles.stim%d, ''Value'', %d);', whichone, value);
        eval(cmd);
        % Set the bookkeeping structure
        handles.stim(whichone) = value;
        if prev ~= value
            global CURRENT_uAMPS;
            CURRENT_uAMPS = handles.START_uAMPS;
            set(handles.currentcurrent, 'String', sprintf('%.2g', CURRENT_uAMPS));
        end
    end
end
update_monitor_electrodes(hObject, eventdata, handles);
guidata(hObject, handles);



% --- Executes on button press in electrode1.
function electrode1_Callback(hObject, eventdata, handles)
electrode_universal_callback(hObject, eventdata, handles);

function electrode2_Callback(hObject, eventdata, handles)
electrode_universal_callback(hObject, eventdata, handles);


% --- Executes on button press in electrode3.
function electrode3_Callback(hObject, eventdata, handles)
electrode_universal_callback(hObject, eventdata, handles);


% --- Executes on button press in electrode4.
function electrode4_Callback(hObject, eventdata, handles)
electrode_universal_callback(hObject, eventdata, handles);


% --- Executes on button press in electrode5.
function electrode5_Callback(hObject, eventdata, handles)
electrode_universal_callback(hObject, eventdata, handles);


% --- Executes on button press in electrode6.
function electrode6_Callback(hObject, eventdata, handles)
electrode_universal_callback(hObject, eventdata, handles);


% --- Executes on button press in electrode7.
function electrode7_Callback(hObject, eventdata, handles)
electrode_universal_callback(hObject, eventdata, handles);


% --- Executes on button press in electrode8.
function electrode8_Callback(hObject, eventdata, handles)
electrode_universal_callback(hObject, eventdata, handles);


% --- Executes on button press in electrode9.
function electrode9_Callback(hObject, eventdata, handles)
electrode_universal_callback(hObject, eventdata, handles);


% --- Executes on button press in electrode10.
function electrode10_Callback(hObject, eventdata, handles)
electrode_universal_callback(hObject, eventdata, handles);


% --- Executes on button press in electrode11.
function electrode11_Callback(hObject, eventdata, handles)
electrode_universal_callback(hObject, eventdata, handles);


% --- Executes on button press in electrode12.
function electrode12_Callback(hObject, eventdata, handles)
electrode_universal_callback(hObject, eventdata, handles);


% --- Executes on button press in electrode13.
function electrode13_Callback(hObject, eventdata, handles)
electrode_universal_callback(hObject, eventdata, handles);

% --- Executes on button press in electrode14.
function electrode14_Callback(hObject, eventdata, handles)
electrode_universal_callback(hObject, eventdata, handles);

% --- Executes on button press in electrode15.
function electrode15_Callback(hObject, eventdata, handles)
electrode_universal_callback(hObject, eventdata, handles);


% --- Executes on button press in electrode16.
function electrode16_Callback(hObject, eventdata, handles)
electrode_universal_callback(hObject, eventdata, handles);



% --- Executes on selection change in electrode.
function monitor_electrode_control_Callback(hObject, eventdata, handles)
handles.monitor_electrode = get(hObject, 'Value'); % Only works because all 16 are present! v(5)=5
update_monitor_electrodes(hObject, eventdata, handles);
guidata(hObject, handles);

% --- Executes during object creation, after setting all properties.
function monitor_electrode_control_CreateFcn(hObject, eventdata, handles)
set(hObject, 'BackgroundColor', [0.8 0.8 0.1]);



function start_timer(hObject, handles)
disable_controls(hObject, handles);
if ~isempty(handles.timer)
    if handles.running
        error('timer:running:already', 'Timer running already?');
    end
    stop(handles.timer);
    delete(handles.timer);
    handles.running = false;
end
handles.timer = timer('Period', handles.INTERSPIKE_S, 'ExecutionMode', 'fixedSpacing');
handles.timer.TimerFcn = {@plexon_control_timer_callback_2, hObject, handles};
handles.timer.StartFcn = {@plexon_start_timer_callback, hObject, handles};
handles.timer.StopFcn = {@plexon_stop_timer_callback, hObject, handles};
handles.timer.ErrorFcn = {@plexon_error_timer_callback, hObject, handles};
start(handles.timer);
guidata(hObject, handles);



% --- Executes on button press in increase.
function increase_Callback(hObject, eventdata, handles)
global change;
change = handles.INCREASE_STEP;
if isempty(handles.timer)
    start_timer(hObject, handles);
end
guidata(hObject, handles);


% --- Executes on button press in decrease.
function decrease_Callback(hObject, eventdata, handles)
global change;
change = 1/handles.INCREASE_STEP;
if isempty(handles.timer)
    start_timer(hObject, handles);
end
guidata(hObject, handles);


% --- Executes on button press in hold.
function hold_Callback(hObject, eventdata, handles)
global change;
change = 1;
if isempty(handles.timer)
    start_timer(hObject, handles);
end
guidata(hObject, handles);


% --- Executes on button press in stop.
function stop_Callback(hObject, eventdata, handles)
if ~isempty(handles.timer)
    disp('Deleting timer');
    stop(handles.timer); % this also stops and closes the Plexon box
    delete(handles.timer);
    handles.timer = [];
    handles.running = false;
end
enable_controls(hObject, handles);
guidata(hObject, handles);



function currentcurrent_Callback(hObject, eventdata, handles)
newcurrent = str2double(get(hObject, 'String'));
global CURRENT_uAMPS;
if isnan(newcurrent)
        set(hObject, 'String', sprintf('%.2g', CURRENT_uAMPS));
elseif newcurrent < handles.START_uAMPS
        CURRENT_uAMPS = handles.START_uAMPS;
elseif newcurrent > handles.MAX_uAMPS
        CURRENT_uAMPS = handles.MAX_uAMPS;
else
        CURRENT_uAMPS = newcurrent;
end
set(hObject, 'String', sprintf('%.2g', CURRENT_uAMPS));
guidata(hObject, handles);


% --- Executes during object creation, after setting all properties.
function currentcurrent_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function disable_controls(hObject, handles)
for i = 1:length(handles.disable_on_run)
        set(handles.disable_on_run{i}, 'Enable', 'off');
end



function enable_controls(hObject, handles)
for i = 1:length(handles.disable_on_run)
        set(handles.disable_on_run{i}, 'Enable', 'on');
end
% Yeah, but we don't want to enable all the "stim" checkboxes, but rather
% only the valid ones.  *sigh*.  They get disabled with the rest of the
% interface on start-stim, and re-enabled on stop-stim, so now let's update
% them as a special case.
for i = 1:16
        if handles.valid(i)
                status = 'on';
        else
                status = 'off';
        end
        cmd = sprintf('set(handles.stim%d, ''Enable'', ''%s'');', i, status);
        eval(cmd);
end


% When any of the "start sequence" buttons is pressed, open the Plexon box
% and do some basic error checking.  Set all channels to nil.
function plexon_start_timer_callback(obj, event, hObject, handles)


global CURRENT_uAMPS;
global change;
global NEGFIRST;

try
    NullPattern.W1 = 0;
    NullPattern.W2 = 0;
    NullPattern.A1 = 0;
    NullPattern.A2 = 0;
    NullPattern.Delay = 0;

    for channel = find(~handles.stim)
        err = PS_SetPatternType(handles.box, channel, 0);
        if err
            ME = MException('plexon:pattern', 'Could not set pattern type on channel %d', channel);
            throw(ME);
        end

        err = PS_SetRectParam2(handles.box, channel, NullPattern);
        if err
                ME = MException('plexon:pattern', 'Could not set NULL pattern parameters on channel %d', channel);
                throw(ME);
        end

        err = PS_SetRepetitions(1, channel, 1);
        if err
            ME = MException('plexon:pattern', 'Could not set repetition on channel %d', channel);
            throw(ME);
        end

        err = PS_LoadChannel(handles.box, channel);
        if err
            ME = MException('plexon:stimulate', 'Could not stimulate on box %d channel %d: %s', handles.box, channel, PS_GetExtendedErrorInfo(err));    
            throw(ME);
        end
    end
catch ME
    disp(sprintf('Caught the error %s (%s).  Shutting down...', ME.identifier, ME.message));
    report = getReport(ME)
    PS_StopStimAllChannels(handles.box);
    handles.running = false;
    guidata(hObject, handles);
    rethrow(ME);
end

guidata(hObject, handles);


function plexon_stop_timer_callback(obj, event, hObject, handles)
err = PS_StopStimAllChannels(handles.box);
if err
    msgbox('ERROR stopping stimulation!!!!');
else
    handles.running = false;
end
guidata(hObject, handles);


function plexon_error_timer_callback(obj, event, hObject, handles)
if handles.running
    err = PS_StopStimAllChannels(handles.box);
    if err
        msgbox('ERROR stopping stimulation!!!!');
    else
        handles.running = false;
    end
end
guidata(hObject, handles);


function stim_universal_callback(hObject, eventdata, handles)
whichone = str2num(hObject.String);
handles.stim(whichone) = get(hObject, 'Value');
update_monitor_electrodes(hObject, eventdata, handles);
global CURRENT_uAMPS;
CURRENT_uAMPS = handles.START_uAMPS;
set(handles.currentcurrent, 'String', sprintf('%.2g', CURRENT_uAMPS));
if handles.stim(whichone)
    handles.monitor_electrode = whichone;
end
update_monitor_electrodes(hObject, eventdata, handles);
guidata(hObject, handles);


function update_monitor_electrodes(hObject, eventdata, handles)
set(handles.monitor_electrode_control, 'Value', handles.monitor_electrode);
if handles.stim(handles.monitor_electrode)  
    set(handles.monitor_electrode_control, 'BackgroundColor', [0.1 0.8 0.1]);
else
    set(handles.monitor_electrode_control, 'BackgroundColor', [0.8 0.8 0.1]);
end
guidata(hObject, handles);

% --- Executes on button press in stim1.
function stim1_Callback(hObject, eventdata, handles)
stim_universal_callback(hObject, eventdata, handles);

% --- Executes on button press in stim2.
function stim2_Callback(hObject, eventdata, handles)
stim_universal_callback(hObject, eventdata, handles);

% --- Executes on button press in stim3.
function stim3_Callback(hObject, eventdata, handles)
stim_universal_callback(hObject, eventdata, handles);

function stim4_Callback(hObject, eventdata, handles)
stim_universal_callback(hObject, eventdata, handles);

% --- Executes on button press in stim5.
function stim5_Callback(hObject, eventdata, handles)
stim_universal_callback(hObject, eventdata, handles);

% --- Executes on button press in stim6.
function stim6_Callback(hObject, eventdata, handles)
stim_universal_callback(hObject, eventdata, handles)

% --- Executes on button press in stim7.
function stim7_Callback(hObject, eventdata, handles)
stim_universal_callback(hObject, eventdata, handles)

% --- Executes on button press in stim8.
function stim8_Callback(hObject, eventdata, handles)
stim_universal_callback(hObject, eventdata, handles)

% --- Executes on button press in stim9.
function stim9_Callback(hObject, eventdata, handles)
stim_universal_callback(hObject, eventdata, handles)

% --- Executes on button press in stim10.
function stim10_Callback(hObject, eventdata, handles)
stim_universal_callback(hObject, eventdata, handles)

% --- Executes on button press in stim11.
function stim11_Callback(hObject, eventdata, handles)
stim_universal_callback(hObject, eventdata, handles)

% --- Executes on button press in stim15.
function stim15_Callback(hObject, eventdata, handles)
stim_universal_callback(hObject, eventdata, handles)

% --- Executes on button press in stim16.
function stim16_Callback(hObject, eventdata, handles)
stim_universal_callback(hObject, eventdata, handles)

% --- Executes on button press in stim14.
function stim14_Callback(hObject, eventdata, handles)
stim_universal_callback(hObject, eventdata, handles)

% --- Executes on button press in stim12.
function stim12_Callback(hObject, eventdata, handles)
stim_universal_callback(hObject, eventdata, handles)

% --- Executes on button press in stim13.
function stim13_Callback(hObject, eventdata, handles)
stim_universal_callback(hObject, eventdata, handles)

% --- Executes on button press in stim_all.
function select_all_valid_Callback(hObject, eventdata, handles)
for i = find(handles.valid)
    cmd = sprintf('set(handles.stim%d, ''Value'', 1);', i);
    eval(cmd);
    handles.stim(i) = 1;
end
update_monitor_electrodes(hObject, eventdata, handles);
guidata(hObject, handles);








function plexon_control_timer_callback_2(obj, event, hObject, handles)


global CURRENT_uAMPS;
global change;
global NEGFIRST;
global VOLTAGE_RANGE_LAST_STIM;

set(handles.currentcurrent, 'String', sprintf('%.2f', CURRENT_uAMPS));
CURRENT_uAMPS = min(handles.MAX_uAMPS, CURRENT_uAMPS * change);

if 0
    %% Emergency shutdown: move mouse out of window!
    oldUnits = get(0,'units');
    set(0,'units','pixels');
    % Get the figure beneath the mouse pointer & mouse pointer pos
    try
       fig = matlab.ui.internal.getPointerWindow;  % HG2: R2014b or newer
    catch
       fig = get(0,'PointerWindow');  % HG1: R2014a or older
    end
    p = get(0,'PointerLocation');
    set(0,'units',oldUnits);

    % Look for quick exit (if mouse pointer is not over any figure)
    if fig==0
        disp('Pausing stimulation until mouse returns to window...');
        return;
    end
end

try

    % Is this the easiest way to define this?  Use GUI soon.  Meanwhile, A is
    % amplitude, W is width, Delay is interphase delay.
    if NEGFIRST
            StimParam.A1 = -CURRENT_uAMPS;
            StimParam.A2 = CURRENT_uAMPS;
    else
            StimParam.A1 = CURRENT_uAMPS;
            StimParam.A2 = -CURRENT_uAMPS;
    end
    StimParam.W1 = handles.HALF_TIME_uS;
    StimParam.W2 = handles.HALF_TIME_uS;
    StimParam.Delay = 0;
    
    NullPattern.W1 = 0;
    NullPattern.W2 = 0;
    NullPattern.A1 = 0;
    NullPattern.A2 = 0;
    NullPattern.Delay = 0;

    which_valid_electrode = get(handles.monitor_electrode_control, 'Value');
    valid_electrode_strings = get(handles.monitor_electrode_control, 'String');
    channel = str2num(valid_electrode_strings{which_valid_electrode});
    % If no channel is selected, just fail silently and let the user figure
    % out what's going on :)
    if channel > 0 & channel <= 16
        err = PS_SetMonitorChannel(handles.box, channel);
        if err
            ME = MException('plexon:monitor', 'Could not set monitor channel to %d', channel);
            throw(ME);
        end
    end
    
    for channel = find(handles.stim)
        err = PS_SetPatternType(handles.box, channel, 0);
        if err
            ME = MException('plexon:pattern', 'Could not set pattern type on channel %d', channel);
            throw(ME);
        end

        err = PS_SetRectParam2(handles.box, channel, StimParam);
        if err
                ME = MException('plexon:pattern', 'Could not set pattern parameters on channel %d', channel);
                throw(ME);
        end
                

        err = PS_SetRepetitions(1, channel, 1);
        if err
            ME = MException('plexon:pattern', 'Could not set repetition on channel %d', channel);
            throw(ME);
        end

        [v, err] = PS_IsWaveformBalanced(handles.box, channel);
        if err
            ME = MException('plexon:stimulate', 'Bad parameter for stimbox %d channel %d', handles.box, channel);
            throw(ME);
        end
        if ~v
            ME = MException('plexon:stimulate:unbalanced', 'Waveform is not balanced for stimbox %d channel %d', handles.box, channel);
            throw(ME);
        end

        err = PS_LoadChannel(handles.box, channel);
        if err
            ME = MException('plexon:stimulate', 'Could not stimulate on box %d channel %d: %s', handles.box, channel, PS_GetExtendedErrorInfo(err));    
            throw(ME);
        end
    end
    
    % Start it!
    handles.NIsession.startBackground;
    err = PS_StartStimAllChannels(handles.box);
    if err
        handles.NIsession.stop;
        ME = MException('plexon:stimulate', 'Could not stimulate on box %d: %s', handles.box, PS_GetExtendedErrorInfo(err));
        throw(ME);
    end
    handles.NIsession.wait;  % This callback needs to be interruptible!  Apparently it is??
    if max(abs(VOLTAGE_RANGE_LAST_STIM)) > handles.VoltageLimit
        ME = MException('plexon:stimulate:brokenElectrode', 'Channel %d may be broken!!', channel);    
        throw(ME);
    end
    

catch ME
    errordlg(ME.message, 'Error', 'modal');
    disp(sprintf('Caught the error %s (%s).  Shutting down...', ME.identifier, ME.message));
    report = getReport(ME)
    PS_StopStimAllChannels(handles.box);
    handles.NIsession.stop;
    handles.running = false;
    guidata(hObject, handles);
    stop_Callback(hObject, eventdata, handles);
    rethrow(ME);
end


guidata(hObject, handles);


