%% Exam PSY4320 fMRI preprocessing and analysis

% Written by: Røskva
% Document created 05/06/25
% Last changed: 08/06/25

%% Steps to make the script work
% Change filepaths to your directory

% Make sure we're in the right place
cd('C:\Users\catba\Documents\Universitetet i Oslo\Våren 2025\PSY4320 Research methods II\Exam')

% Open SPM
addpath('C:\Users\catba\Documents\Universitetet i Oslo\Våren 2025\PSY4320 Research methods II\spm12_for_matlab\spm12')
spm fmri


%% Preprocessing pipeline

% Uses these parameters
% Number of slices: 33
% TR: 1
% TA: 1-1/33
% Slice order: 33:-1:1
% Reference slice: 17

spm('defaults','fmri');
spm_jobman('initcfg');

subjects = {'ns03', 'ns04', 'ns05', 'ns06'};
runs = {'run01', 'run02', 'run03', 'run04'};

base_dir = 'C:\Users\catba\Documents\Universitetet i Oslo\Våren 2025\PSY4320 Research methods II\Exam\PSY4320_course_data';
out_dir = 'C:\Users\catba\Documents\Universitetet i Oslo\Våren 2025\PSY4320 Research methods II\Exam\exam_submission';

func_filenames = { ...
    {'ff_ns03_run01_4_1.nii','ff_ns03_run02_5_1.nii','ff_ns03_run03_6_1.nii','ff_ns03_run04_7_1.nii'}, ...
    {'ff_ns04_run01_5_1.nii','ff_ns04_run02_6_1.nii','ff_ns04_run03_7_1.nii','ff_ns04_run04_8_1.nii'}, ...
    {'ff_ns05_run01_5_1.nii','ff_ns05_run02_6_1.nii','ff_ns05_run03_7_1.nii','ff_ns05_run04_8_1.nii'}, ...
    {'ff_ns06_run01_5_1.nii','ff_ns06_run02_6_1.nii','ff_ns06_run03_7_1.nii','ff_ns06_run04_8_1.nii'} ...
    };

anat_filenames = { ...
    'anon_ss_ns03_t1.nii', ...
    'anon_ss_ns04_t1.nii', ...
    'anon_ss_ns05_t1.nii', ...
    'anon_ss_ns06_t1.nii' ...
    };

for s = 1:length(subjects)
    subject = subjects{s};
    anat_file = fullfile(base_dir, subject, 'run01', anat_filenames{s});

    for r = 1:length(runs)
        run = runs{r};
        fprintf('Processing subject %s, run %s\n', subject, run);
        func_file = fullfile(base_dir, subject, run, func_filenames{s}{r});
        anat_file_run = fullfile(base_dir, subject, run, anat_filenames{s}); % anatomical for coreg

        % 1. SLICE TIMING CORRECTION (per run)
        clear matlabbatch
        disp(['Looking for functional file: ' func_file]);
        if ~exist(func_file, 'file')
            error('Functional file not found: %s', func_file);
        end

        st_scans = spm_select('ExtFPList', fileparts(func_file), ['^' func_filenames{s}{r}], 1:192);
        if isempty(st_scans)
            error('No volumes found for slice timing in: %s', func_file);
        end
        matlabbatch{1}.spm.temporal.st.scans = {cellstr(st_scans)}; % Must be a cell array

        matlabbatch{1}.spm.temporal.st.nslices = 33;
        matlabbatch{1}.spm.temporal.st.tr = 1;
        matlabbatch{1}.spm.temporal.st.ta = 1 - 1/33;
        matlabbatch{1}.spm.temporal.st.so = 33:-1:1;
        matlabbatch{1}.spm.temporal.st.refslice = 17;
        st_jobfile = fullfile(out_dir, sprintf('%s_slicetime_%s.mat', subject, run));
        save(st_jobfile, 'matlabbatch');
        spm_jobman('run', matlabbatch);


        % 2. COREGISTRATION (per run)
        clear matlabbatch
        a_func_file = spm_file(func_file, 'prefix', 'a');
        disp(['Looking for slice-timed file for coreg: ' a_func_file]);
        if ~exist(a_func_file, 'file')
            error('After slice timing, file not found: %s', a_func_file);
        end
        if ~exist(anat_file_run, 'file')
            error('Anatomical file for coregistration not found: %s', anat_file_run);
        end

        % Automatically determine the number of frames in the functional file
        V = spm_vol(a_func_file);
        nFrames = numel(V);

        % Prepare list of "other" images: frames 2 to end
        other_imgs = cell(nFrames-1,1);
        for k = 2:nFrames
            other_imgs{k-1} = sprintf('%s,%d', a_func_file, k);
        end

        matlabbatch{1}.spm.spatial.coreg.estimate.ref    = {anat_file_run};                   % T1 as reference
        matlabbatch{1}.spm.spatial.coreg.estimate.source = {sprintf('%s,1', a_func_file)};    % First functional frame as source
        matlabbatch{1}.spm.spatial.coreg.estimate.other  = other_imgs;                        % All other frames as "other"

        coreg_jobfile = fullfile(out_dir, sprintf('%s_coregister_%s.mat', subject, run));
        save(coreg_jobfile, 'matlabbatch');
        spm_jobman('run', matlabbatch);
    end

    % 3. SEGMENTATION (once per subject, after all runs are coregistered)
    clear matlabbatch
    disp(['Looking for anatomical file for segmentation: ' anat_file]);
    if ~exist(anat_file, 'file')
        error('Anatomical file for segmentation not found: %s', anat_file);
    end
    matlabbatch{1}.spm.spatial.preproc.channel.vols  = {anat_file};

    matlabbatch{1}.spm.spatial.preproc.channel.write = [0 1];
    matlabbatch{1}.spm.spatial.preproc.warp.write    = [0 1];
    seg_jobfile = fullfile(out_dir, sprintf('%s_segment.mat', subject));
    save(seg_jobfile, 'matlabbatch');
    spm_jobman('run', matlabbatch);

    % Get deformation field for normalization
    def_file = spm_file(anat_file, 'prefix', 'y_', 'ext', 'nii');

    for rr = 1:length(runs)
        run = runs{rr};
        func_file = fullfile(base_dir, subject, run, func_filenames{s}{rr});
        a_func_file = spm_file(func_file, 'prefix', 'a');

        % 4. NORMALIZATION (per run, using y_* from segmentation)
        clear matlabbatch
        disp(['Looking for deformation field: ' def_file]);
        if ~exist(def_file, 'file')
            error('Deformation field not found: %s', def_file);
        end
        disp(['Looking for coregistered functional for normalization: ' a_func_file]);
        if ~exist(a_func_file, 'file')
            error('Coregistered file for normalization not found: %s', a_func_file);
        end
        matlabbatch{1}.spm.spatial.normalise.write.subj.def      = {def_file};
        matlabbatch{1}.spm.spatial.normalise.write.subj.resample = {a_func_file};

        matlabbatch{1}.spm.spatial.normalise.write.woptions.vox  = [3 3 3];
        norm_jobfile = fullfile(out_dir, sprintf('%s_normalise_%s.mat', subject, run));
        save(norm_jobfile, 'matlabbatch');
        spm_jobman('run', matlabbatch);

        % 5. SMOOTHING (per run)
        clear matlabbatch
        w_func_file = spm_file(a_func_file, 'prefix', 'w');
        disp(['Looking for normalized file for smoothing: ' w_func_file]);
        if ~exist(w_func_file, 'file')
            error('Normalized file for smoothing not found: %s', w_func_file);
        end
        matlabbatch{1}.spm.spatial.smooth.data = {w_func_file};

        matlabbatch{1}.spm.spatial.smooth.fwhm = [6 6 6];
        smooth_jobfile = fullfile(out_dir, sprintf('%s_smooth_%s.mat', subject, run));
        save(smooth_jobfile, 'matlabbatch');
        spm_jobman('run', matlabbatch);
    end

end


%% Setting up the design & first level analysis

%% IMPORTANT - % mov_reg_all.txt in glm_smooth-folders need to be split into mov_reg_short_1 etc.

% FIXED CONTRAST CREATION FOR ALL SUBJECTS
% This script creates working contrasts for all subjects using the correct approach

% Setup paths
base_path = 'C:\Users\catba\Documents\Universitetet i Oslo\Våren 2025\PSY4320 Research methods II\Exam\PSY4320_course_data';
submission_path = 'C:\Users\catba\Documents\Universitetet i Oslo\Våren 2025\PSY4320 Research methods II\Exam\exam_submission';

% List of subjects
subjects = {'ns03', 'ns04', 'ns05', 'ns06'};

for s = 1:length(subjects)
    subj = subjects{s};
    fprintf('\n=== Creating contrasts for subject: %s ===\n', subj);
    
    % Navigate to subject's GLM folder
    subj_dir = fullfile(base_path, subj, 'glm_smooth');
    cd(subj_dir);
    
    % Load SPM.mat
    load('SPM.mat');
    
    % Check design matrix rank
    X = SPM.xX.X;
    rank_X = rank(X);
    fprintf('Design matrix rank: %d (out of %d columns)\n', rank_X, size(X, 2));
    
    % Find estimable columns
    [Q, R, P] = qr(X, 0);
    estimable_cols = sort(P(1:rank(X)));
    
    % Create contrast vectors based on the pattern we found for ns03
    % These indices should be similar across subjects since they have the same design
    
    % CONTRAST 1: Pink noise emotional > neutral
    pn_contrast = zeros(1, size(X, 2));
    
    % Pink noise neutral indices (conditions 1,2,3 per session, but only estimable ones)
    pn_neu_indices = [];
    pn_emo_indices = [];
    
    for sess = 1:4
        sess_start = SPM.Sess(sess).col(1);
        % Pink noise neutral: conditions 1,2,3 (indices 0,1,2)
        pn_neu_indices = [pn_neu_indices, sess_start + [0, 1, 2]];
        % Pink noise emotional: conditions 7,8,9 (indices 6,7,8)
        pn_emo_indices = [pn_emo_indices, sess_start + [6, 7, 8]];
    end
    
    % Only use estimable columns
    pn_neu_estimable = intersect(pn_neu_indices, estimable_cols);
    pn_emo_estimable = intersect(pn_emo_indices, estimable_cols);
    
    fprintf('Pink noise neutral estimable indices: '); disp(pn_neu_estimable);
    fprintf('Pink noise emotional estimable indices: '); disp(pn_emo_estimable);
    
    if ~isempty(pn_neu_estimable) && ~isempty(pn_emo_estimable)
        pn_contrast(pn_neu_estimable) = -1/length(pn_neu_estimable);
        pn_contrast(pn_emo_estimable) = 1/length(pn_emo_estimable);
    end
    
    % CONTRAST 2: Speech noise emotional > neutral
    sn_contrast = zeros(1, size(X, 2));
    
    sn_neu_indices = [];
    sn_emo_indices = [];
    
    for sess = 1:4
        sess_start = SPM.Sess(sess).col(1);
        % Speech noise neutral: conditions 4,5,6 (indices 3,4,5)
        sn_neu_indices = [sn_neu_indices, sess_start + [3, 4, 5]];
        % Speech noise emotional: conditions 10,11,12 (indices 9,10,11)
        sn_emo_indices = [sn_emo_indices, sess_start + [9, 10, 11]];
    end
    
    % Only use estimable columns
    sn_neu_estimable = intersect(sn_neu_indices, estimable_cols);
    sn_emo_estimable = intersect(sn_emo_indices, estimable_cols);
    
    fprintf('Speech noise neutral estimable indices: '); disp(sn_neu_estimable);
    fprintf('Speech noise emotional estimable indices: '); disp(sn_emo_estimable);
    
    if ~isempty(sn_neu_estimable) && ~isempty(sn_emo_estimable)
        sn_contrast(sn_neu_estimable) = -1/length(sn_neu_estimable);
        sn_contrast(sn_emo_estimable) = 1/length(sn_emo_estimable);
    end
    
    fprintf('Contrast sums: PN=%.10f, SN=%.10f\n', sum(pn_contrast), sum(sn_contrast));
    
    % Create and run contrast batch
    clear matlabbatch
    spm_file = fullfile(pwd, 'SPM.mat');
    matlabbatch{1}.spm.stats.con.spmmat = {spm_file};
    
    % Add contrasts
    matlabbatch{1}.spm.stats.con.consess{1}.tcon.name = 'pn_det_emo_gt_neu';
    matlabbatch{1}.spm.stats.con.consess{1}.tcon.weights = pn_contrast;
    matlabbatch{1}.spm.stats.con.consess{1}.tcon.sessrep = 'none';
    
    matlabbatch{1}.spm.stats.con.consess{2}.tcon.name = 'sn_det_emo_gt_neu';
    matlabbatch{1}.spm.stats.con.consess{2}.tcon.weights = sn_contrast;
    matlabbatch{1}.spm.stats.con.consess{2}.tcon.sessrep = 'none';
    
    % Save the contrast batch (ITEM 12)
    contrast_filename = fullfile(submission_path, [subj '_contrast.mat']);
    save(contrast_filename, 'matlabbatch');
    fprintf('Saved contrast batch: %s\n', contrast_filename);
    
    % Run the contrasts
    try
        spm_jobman('run', matlabbatch);
        fprintf('SUCCESS: Contrasts created for %s!\n', subj);
        
        % Check for contrast files
        if exist('con_0001.nii', 'file')
            fprintf('✓ con_0001.nii created\n');
        end
        if exist('con_0002.nii', 'file')
            fprintf('✓ con_0002.nii created\n');
        end
        
    catch ME
        fprintf('FAILED for %s: %s\n', subj, ME.message);
    end
end

fprintf('\n=== CONTRAST CREATION COMPLETE ===\n');
fprintf('Next steps:\n');
fprintf('1. Take screenshots using SPM Results for each subject\n');
fprintf('2. Copy contrast files to group folders\n');

%% SECOND-LEVEL GROUP ANALYSIS
% This script creates 2nd-level analyses for both contrasts

% Setup paths
base_path = 'C:\Users\catba\Documents\Universitetet i Oslo\Våren 2025\PSY4320 Research methods II\Exam\PSY4320_course_data';
submission_path = 'C:\Users\catba\Documents\Universitetet i Oslo\Våren 2025\PSY4320 Research methods II\Exam\exam_submission';
group_path = fullfile(base_path, 'group_analysis');

subjects = {'ns03', 'ns04', 'ns05', 'ns06'};

%% ANALYSIS 1: CON01 (Pink noise: emotional > neutral)
fprintf('\n=== SECOND-LEVEL ANALYSIS 1: CON01 (Pink noise) ===\n');

% Working directory for con01 analysis
con01_dir = fullfile(group_path, 'con01', 'group_2level');
cd(con01_dir);

% Collect all con01 files (pink noise contrasts)
con01_files = {};
for s = 1:length(subjects)
    subj = subjects{s};
    con_file = fullfile(con01_dir, [subj '_con_0001.nii']);
    if exist(con_file, 'file')
        con01_files{end+1} = con_file;
        fprintf('Found: %s\n', con_file);
    else
        warning('Missing file: %s', con_file);
    end
end

fprintf('Total con01 files found: %d\n', length(con01_files));

% STEP 15: Design specification for con01
clear matlabbatch
matlabbatch{1}.spm.stats.factorial_design.dir = {con01_dir};
matlabbatch{1}.spm.stats.factorial_design.des.t1.scans = con01_files';
matlabbatch{1}.spm.stats.factorial_design.cov = struct('c', {}, 'cname', {}, 'iCFI', {}, 'iCC', {});
matlabbatch{1}.spm.stats.factorial_design.multi_cov = struct('files', {}, 'iCFI', {}, 'iCC', {});
matlabbatch{1}.spm.stats.factorial_design.masking.tm.tm_none = 1;
matlabbatch{1}.spm.stats.factorial_design.masking.im = 1;
matlabbatch{1}.spm.stats.factorial_design.masking.em = {''};
matlabbatch{1}.spm.stats.factorial_design.globalc.g_omit = 1;
matlabbatch{1}.spm.stats.factorial_design.globalm.gmsca.gmsca_no = 1;
matlabbatch{1}.spm.stats.factorial_design.globalm.glonorm = 1;

% Save design batch for con01
design_con01_file = fullfile(submission_path, 'con01_design.mat');
save(design_con01_file, 'matlabbatch');
fprintf('Saved con01 design: %s\n', design_con01_file);

% Run design for con01
try
    spm_jobman('run', matlabbatch);
    fprintf('✓ Con01 design specification completed\n');
catch ME
    fprintf('✗ Con01 design failed: %s\n', ME.message);
end

% STEP 16: Estimation for con01
clear matlabbatch
matlabbatch{1}.spm.stats.fmri_est.spmmat = {fullfile(con01_dir, 'SPM.mat')};
matlabbatch{1}.spm.stats.fmri_est.write_residuals = 0;
matlabbatch{1}.spm.stats.fmri_est.method.Classical = 1;

% Save estimate batch for con01
estimate_con01_file = fullfile(submission_path, 'con01_estimate.mat');
save(estimate_con01_file, 'matlabbatch');
fprintf('Saved con01 estimate: %s\n', estimate_con01_file);

% Run estimation for con01
try
    spm_jobman('run', matlabbatch);
    fprintf('✓ Con01 estimation completed\n');
catch ME
    fprintf('✗ Con01 estimation failed: %s\n', ME.message);
end

% STEP 17: Contrast for con01 (one-sample t-test against zero)
clear matlabbatch
matlabbatch{1}.spm.stats.con.spmmat = {fullfile(con01_dir, 'SPM.mat')};
matlabbatch{1}.spm.stats.con.consess{1}.tcon.name = 'group_pn_emo_gt_neu';
matlabbatch{1}.spm.stats.con.consess{1}.tcon.weights = 1;  % Test if group mean > 0
matlabbatch{1}.spm.stats.con.consess{1}.tcon.sessrep = 'none';

% Save contrast batch for con01
contrast_con01_file = fullfile(submission_path, 'con01_contrast.mat');
save(contrast_con01_file, 'matlabbatch');
fprintf('Saved con01 contrast: %s\n', contrast_con01_file);

% Run contrast for con01
try
    spm_jobman('run', matlabbatch);
    fprintf('✓ Con01 contrast completed\n');
catch ME
    fprintf('✗ Con01 contrast failed: %s\n', ME.message);
end

%% ANALYSIS 2: CON02 (Speech noise: emotional > neutral)
fprintf('\n=== SECOND-LEVEL ANALYSIS 2: CON02 (Speech noise) ===\n');

% Working directory for con02 analysis
con02_dir = fullfile(group_path, 'con02', 'group_2level');
cd(con02_dir);

% Collect all con02 files (speech noise contrasts)
con02_files = {};
for s = 1:length(subjects)
    subj = subjects{s};
    con_file = fullfile(con02_dir, [subj '_con_0002.nii']);
    if exist(con_file, 'file')
        con02_files{end+1} = con_file;
        fprintf('Found: %s\n', con_file);
    else
        warning('Missing file: %s', con_file);
    end
end

fprintf('Total con02 files found: %d\n', length(con02_files));

% STEP 15: Design specification for con02
clear matlabbatch
matlabbatch{1}.spm.stats.factorial_design.dir = {con02_dir};
matlabbatch{1}.spm.stats.factorial_design.des.t1.scans = con02_files';
matlabbatch{1}.spm.stats.factorial_design.cov = struct('c', {}, 'cname', {}, 'iCFI', {}, 'iCC', {});
matlabbatch{1}.spm.stats.factorial_design.multi_cov = struct('files', {}, 'iCFI', {}, 'iCC', {});
matlabbatch{1}.spm.stats.factorial_design.masking.tm.tm_none = 1;
matlabbatch{1}.spm.stats.factorial_design.masking.im = 1;
matlabbatch{1}.spm.stats.factorial_design.masking.em = {''};
matlabbatch{1}.spm.stats.factorial_design.globalc.g_omit = 1;
matlabbatch{1}.spm.stats.factorial_design.globalm.gmsca.gmsca_no = 1;
matlabbatch{1}.spm.stats.factorial_design.globalm.glonorm = 1;

% Save design batch for con02
design_con02_file = fullfile(submission_path, 'con02_design.mat');
save(design_con02_file, 'matlabbatch');
fprintf('Saved con02 design: %s\n', design_con02_file);

% Run design for con02
try
    spm_jobman('run', matlabbatch);
    fprintf('✓ Con02 design specification completed\n');
catch ME
    fprintf('✗ Con02 design failed: %s\n', ME.message);
end

% STEP 16: Estimation for con02
clear matlabbatch
matlabbatch{1}.spm.stats.fmri_est.spmmat = {fullfile(con02_dir, 'SPM.mat')};
matlabbatch{1}.spm.stats.fmri_est.write_residuals = 0;
matlabbatch{1}.spm.stats.fmri_est.method.Classical = 1;

% Save estimate batch for con02
estimate_con02_file = fullfile(submission_path, 'con02_estimate.mat');
save(estimate_con02_file, 'matlabbatch');
fprintf('Saved con02 estimate: %s\n', estimate_con02_file);

% Run estimation for con02
try
    spm_jobman('run', matlabbatch);
    fprintf('✓ Con02 estimation completed\n');
catch ME
    fprintf('✗ Con02 estimation failed: %s\n', ME.message);
end

% STEP 17: Contrast for con02 (one-sample t-test against zero)
clear matlabbatch
matlabbatch{1}.spm.stats.con.spmmat = {fullfile(con02_dir, 'SPM.mat')};
matlabbatch{1}.spm.stats.con.consess{1}.tcon.name = 'group_sn_emo_gt_neu';
matlabbatch{1}.spm.stats.con.consess{1}.tcon.weights = 1;  % Test if group mean > 0
matlabbatch{1}.spm.stats.con.consess{1}.tcon.sessrep = 'none';

% Save contrast batch for con02
contrast_con02_file = fullfile(submission_path, 'con02_contrast.mat');
save(contrast_con02_file, 'matlabbatch');
fprintf('Saved con02 contrast: %s\n', contrast_con02_file);

% Run contrast for con02
try
    spm_jobman('run', matlabbatch);
    fprintf('✓ Con02 contrast completed\n');
catch ME
    fprintf('✗ Con02 contrast failed: %s\n', ME.message);
end

%% SUMMARY
fprintf('\n=== SECOND-LEVEL ANALYSIS COMPLETE ===\n');
fprintf('Files created for submission:\n');
fprintf('- %s\n', design_con01_file);
fprintf('- %s\n', estimate_con01_file);
fprintf('- %s\n', contrast_con01_file);
fprintf('- %s\n', design_con02_file);
fprintf('- %s\n', estimate_con02_file);
fprintf('- %s\n', contrast_con02_file);
fprintf('\nNext step: Take screenshots using SPM Results for each contrast\n');
fprintf('Con01 SPM.mat: %s\n', fullfile(con01_dir, 'SPM.mat'));
fprintf('Con02 SPM.mat: %s\n', fullfile(con02_dir, 'SPM.mat'));
