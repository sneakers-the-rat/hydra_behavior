% SCRIPT FOR ANALYZING NEW SOMERSAULTING DATA WITH PRE-TRAINED CLASSIFIERS

% reset random generator
rng(1000);

%% set path
addpath(genpath('/home/sh3276/work/code/hydra_behavior'));
addpath(genpath('/home/sh3276/software/inria_fisher_v1/yael_v371/matlab'));

%% setup parameters
param = struct();

% file information
param.fileIndx = {[502,504,506],[304,310],640};

param.datastr = '20170321';
param.srcstr = {'20161121','20161215','20161105'};
param.mstr = '20170223';

param.pbase = '/home/sh3276/work/results';
param.mbase = '/home/sh3276/work/results';
param.dbase = '/home/sh3276/work/data/';
param.dstr = {'medium_swap','dark_light','long_recordings'};
for n = 1:length(param.srcstr)
    param.fvpath{n} = sprintf('%s/%s/fv/%s/',param.pbase,param.dstr{n},param.srcstr{n});
    param.dpath{n} = sprintf('%s/%s/',param.dbase,param.dstr{n});
end
param.svmpath = sprintf('%s/ss_svm/%s/',param.pbase,param.datastr);
param.parampath = sprintf('%s/param/',param.pbase);

% DT parameters
param.dt.src = '/home/sh3276/software/dense_trajectory_release_v1.2/release_novis';
param.dt.W = 5;
param.dt.L = 15;
param.dt.tlen = 5; % in seconds
param.dt.s = 1;
param.dt.t = 1;
param.dt.N = 32;
param.dt.thresh = 0.5;

param.annotype = 13;
param.fr = 5;
param.timeStep = param.dt.tlen*param.fr;
param.infostr = sprintf('L_%u_W_%u_N_%u_s_%u_t_%u_step_%u',param.dt.L,...
    param.dt.W,param.dt.N,param.dt.s,param.dt.t,param.timeStep);

% SVM parameters
param.svm.src = '/home/sh3276/software/libsvm';
param.svm.percTrain = 0.9;
param.svm.kernel = 3; % rbf kernel
param.svm.probest = 1; % true
param.svm.name = [param.infostr '_drFVall_annoType' num2str(param.annotype)];

param.keepDim = 5;

%% check if all directories exist
for n = 1:length(param.fvpath)
    if exist(param.fvpath{n},'dir')~=7
        error('Incorrect data path: %s\n',param.fvpath{n})
    end
end
if exist(param.svmpath,'dir')~=7
    mkdir(param.svmpath);
    fprintf('created directory %s\n',param.svmpath);
end

% save parameters to file
dispStructNested(param,[],[param.parampath 'expt_param_' param.datastr '.txt']);
save([param.parampath 'expt_param_' param.datastr '.mat'],'param');

%% generate SVM samples
for n = 1:length(param.fileIndx)
    for ii = 1:length(param.fileIndx{n})
        movieParam = paramAll(param.dpath{n},param.fileIndx{n}(ii));
        sample = load([param.fvpath{n} movieParam.fileName '_' param.infostr '_drFVall.mat']);
        sample = sample.drFVall;
        label = zeros(size(sample,1),1);
        
        % write to libsvm format file
        fprintf('writing SVM sample: %s\n',movieParam.fileName);
        gnLibsvmFile(label,sample(:,1:param.keepDim),[param.svmpath param.svm.name '_' movieParam.fileName '.txt']);
    end
end

%% SVM
for n = 1:length(param.fileIndx)
    
    num_file = length(param.fileIndx{n});
    fnames = '';
    for ii = 1:num_file
        fnames = [fnames sprintf('"%s" ',fileinfo(param.fileIndx{n}(ii)))];
    end
    fnames = fnames(1:end-1);
    modelpath = sprintf('%s/svm/%s/',param.mbase,param.mstr);
    writeSVMTestScript(param.svm.src,param.svmpath,modelpath,param.svm.name,fnames);
    try 
        status = system(sprintf('bash %ssvmClassifyIndv.sh',param.svmpath));
    catch ME
        error('Error running svm classification');
    end

    % save prediction result to mat files
    for ii = 1:num_file
        fname = fileinfo(param.fileIndx{n}(ii));
        [pred,pred_score,pred_soft] = saveSVMpred(param.svmpath,...
            [param.svm.name '_' fileinfo(param.fileIndx{n}(ii))]);
        save([param.svmpath fname '_annotype' num2str(param.annotype) ...
            '_pred_results.mat'],'pred','pred_score','pred_soft','-v7.3');
    end
end

