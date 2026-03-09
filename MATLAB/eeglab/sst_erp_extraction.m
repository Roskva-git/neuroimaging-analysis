%% Batch processing pipeline for SST data with ICA
% Author: Røskva
% Date: 31.05.25
%% 0. Initialize EEGLAB and set paths
addpath('\\hume.uio.no\...\eeglab2025.0.0', ...
    '\\hypatia.uio.no\lh-sv-psi\...\parent_folder\', ...
    '\\hypatia.uio.no\lh-sv-psi\...\func\');
eeglab;  % Start EEGLAB

% Define folders
in_folder = '\\hypatia.uio.no\lh-sv-psi\...\3_epoched\';
out_folder = '\\hypatia.uio.no\lh-sv-psi\...\4_ERPs\';

% Get all .set files in the epoch folder
set_files = dir(fullfile(in_folder, '*.set'));


% Load one file to get the number of time points
EEG = pop_loadset(fullfile(in_folder, set_files(f).name));
n_timepoints = length(EEG.times);
n_participants = length(set_files);

% Initialize structure array
ERP_all = struct('participant', {}, 'condition', {}, 'ERP', {}, 'times', {});

% Load one file to get the number of time points (using first file)
EEG = pop_loadset(fullfile(in_folder, set_files(1).name));
n_timepoints = length(EEG.times);


% Loop over each file
for f = 1:length(set_files)
    try
        % Get file info
        [~, base_name, ~] = fileparts(set_files(f).name); % e.g., 'SST_152_1'
        disp(['Processing: ' base_name]);
		
		% Extract participant ID and condition from filename
        parts = split(base_name, '_');
        participant_id = parts{2};             % e.g., '152'
        condition = parts{end};                % e.g., 'validGo'
		

        %% Load Data
        EEG = pop_loadset(fullfile(in_folder, set_files(f).name));
        
        %% Find ERPs

        % Find the index of FCz in the channel list
        chan_labels = {EEG.chanlocs.labels};
        fcz_index = find(strcmpi(chan_labels, 'FCz'));

        ERP_FCz = EEG.data(fcz_index,:,:);
        ERP_FCz_mean = squeeze(mean(ERP_FCz, 3));
		
        
		% Add to structure array
        ERP_all(f).participant = participant_id;
        ERP_all(f).condition = condition;
        ERP_all(f).ERP = ERP_FCz_mean;
		ERP_all(f).times = EEG.times;
		
        %Plot each participant's mean ERP
        %figure;
        %plot(EEG.times, ERP_FCz_mean);
        %title([participant_id ' ' condition]);
        %xlabel('Time (ms)');
        %ylabel('Amplitude (µV)');

        catch ME
      % Display error in console
         disp(['ERROR processing ' set_files(f).name ':']);
         disp(getReport(ME, 'extended', 'hyperlinks', 'off'));
      % Log to error file with timestamp
        fid = fopen(fullfile(out_folder, 'processing_errors.log'), 'a');
        fprintf(fid, '[%s] Error in %s:\n%s\n\n', ...
            datetime("now"), set_files(f).name, getReport(ME));
        fclose(fid);
    end
end
save(fullfile(out_folder, 'ERP_FCz_struct.mat'), 'ERP_all');
disp(['Mean ERPs saved to: ' out_folder]);
disp(['Batch processing complete for ' num2str(n_participants) ' files.'])
