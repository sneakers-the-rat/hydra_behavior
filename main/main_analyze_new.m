% MAIN ANALYSIS SCRIPT

% reset random generator
rng(1000);

%% set path
addpath(genpath('/home/sh3276/work/code/hydra_behavior'));
addpath(genpath('/home/sh3276/software/inria_fisher_v1/yael_v371/matlab'));

%% setup parameters
param = struct();

% file information
% param.fileIndx = 645:657;
% param.fileIndx = [502,504,506]; % for ss
param.fileIndx = [304,328]; % for ss

param.datastr = '20161121';
param.mstr = '20161019';

param.pbase = '/home/sh3276/work/results/dark_light';
param.mbase = '/home/sh3276/work/results';
param.dpath = '/home/sh3276/work/data/dark_light/';
param.segpath = sprintf('%s/seg/%s/',param.pbase,param.datastr);
param.segvidpath = sprintf('%s/segvid/%s/',param.pbase,param.datastr);
param.dtpath = sprintf('%s/dt/%s/',param.pbase,param.datastr);
param.dtmatpath = sprintf('%s/dt/%s/mat/',param.pbase,param.datastr);
param.fvpath = sprintf('%s/fv/%s/',param.pbase,param.datastr);
param.svmpath = sprintf('%s/svm/%s/',param.pbase,param.datastr);
param.tsnepath = sprintf('%s/tsne/%s/',param.pbase,param.datastr);
param.parampath = sprintf('%s/param/',param.pbase);

% segmentation/registration parameters
param.seg.numRegion = 3;
param.seg.skipStep = 1;
param.seg.outputsz = [300,300];
param.seg.ifscale = 1;

% DT parameters
param.dt.src = '/home/sh3276/software/dense_trajectory_release_v1.2/release_v4';
param.dt.W = 5;
param.dt.L = 15;
param.dt.tlen = 5; % in seconds
param.dt.s = 1;
param.dt.t = 1;
param.dt.N = 32;
param.dt.thresh = 0.5;

param.annotype = 5;
param.fr = 5;
param.timeStep = param.dt.tlen*param.fr;
param.infostr = sprintf('L_%u_W_%u_N_%u_s_%u_t_%u_step_%u',param.dt.L,...
    param.dt.W,param.dt.N,param.dt.s,param.dt.t,param.timeStep);

% FV parameters
param.fv.gmmpath = sprintf('%s/fv/%s/',param.mbase,param.mstr);
param.fv.K = 128;
param.fv.ci = 90;
param.fv.intran = 0;
param.fv.powern = 1;
param.fv.featstr = {'hof','hog','mbhx','mbhy'};
param.fv.featlen = [9,8,8,8];
param.fv.numPatch = param.dt.s^2*param.dt.t;

% SVM parameters
param.svm.src = '/home/sh3276/software/libsvm';
param.svm.percTrain = 0.9;
param.svm.kernel = 3; % rbf kernel
param.svm.probest = 1; % true
param.svm.name = [param.infostr '_drFVall_annoType' num2str(param.annotype)];

% embedding parameters
param.tsne.distType = 'euc';
param.tsne.closeMatPool = true;
param.tsne.perplexity = 16;
param.tsne.training_perplexity = 16;
param.tsne = setRunParameters(param.tsne);
param.tsne.percTrain = 0.8;

%% check if all directories exist
if exist(param.dpath,'dir')~=7
    error('Incorrect data path')
end
if exist(param.segpath,'dir')~=7
    fprintf('creating directory %s...\n',param.segpath);
    mkdir(param.segpath);
end
if exist(param.segvidpath,'dir')~=7
    fprintf('creating directory %s...\n',param.segpath);
    mkdir(param.segvidpath);
end
if exist(param.dtpath,'dir')~=7
    fprintf('creating directory %s...\n',param.dtpath);
    mkdir(param.dtpath);
end
if exist(param.dtmatpath,'dir')~=7
    fprintf('creating directory %s...\n',param.dtmatpath);
    mkdir(param.dtmatpath);
end
if exist(param.fvpath,'dir')~=7
    fprintf('creating directory %s...\n',param.fvpath);
    mkdir(param.fvpath);
end
if exist(param.svmpath,'dir')~=7
    fprintf('creating directory %s...\n',param.svmpath);
    mkdir(param.svmpath);
end
if exist(param.tsnepath,'dir')~=7
    fprintf('creating directory %s...\n',param.tsnepath);
    mkdir(param.tsnepath);
end
if exist(param.parampath,'dir')~=7
    fprintf('creating directory %s...\n',param.parampath);
    mkdir(param.parampath);
end

% save parameters to file
dispStructNested(param,[],[param.parampath 'expt_param_' param.datastr '.txt']);

%% segmentation and registration
numfile = length(param.fileIndx);

% segmentation
for n = 1:numfile
    movieParam = paramAll(param.dpath,param.fileIndx(n));
    fprintf('segmentation of %s...\n',movieParam.fileName);
    [segAll,theta,centroid,a,b] = runBPSegmentation(movieParam);
    save([param.segpath movieParam.fileName '_seg.mat'],'segAll','theta',...
        'centroid','a','b','-v7.3');
end

% make registered video clips
for n = 1:numfile

    movieParam = paramAll(param.dpath,param.fileIndx(n));
    fprintf('processing %s...\n',movieParam.fileName);
    
    % registration and make scaled video clips
    load([param.segpath movieParam.fileName '_seg.mat']);
    regSeg = registerSegmentMask(segAll,theta,centroid,param.timeStep*param.seg.skipStep);
    segmat = makeRegisteredVideo(param.fileIndx(n),regSeg,param.timeStep,param.seg.skipStep,...
        param.dpath,param.segpath,param.segvidpath,param.seg.ifscale,param.seg.outputsz);
    save([param.segpath movieParam.fileName '_scaled_reg_seg_step_' ...
        num2str(param.timeStep) '.mat'],'segmat','-v7.3');

end

clear segmat

%% run Dense Trajectories in terminal
% generate the script to run DT and save to dt result directory
writeDTscript(param);

% run DT
try 
%     system(sprintf('chmod +x %srunDT.sh',param.dtpath));
    status = system(sprintf('bash %srunDT.sh',param.dtpath));
catch ME
    error('Error running DenseTrajectoris');
end

%% extract DT features
for i = 1:length(param.fileIndx)
    
    % load features
    movieParam = paramAll(param.dpath,param.fileIndx(i));
    fprintf('extracting features %s...\n',movieParam.fileName);
    load([param.segpath movieParam.fileName '_scaled_reg_seg_step_'...
        num2str(param.timeStep) '.mat']);
    [trajAll,hofAll,hogAll,mbhxAll,mbhyAll,coordAll] = extractRegionTwDT...
        (movieParam,param.dtpath,segmat,param.seg.numRegion,param.dt);

    % save features
    save([param.dtmatpath movieParam.fileName '_' param.infostr '_traj.mat'],'trajAll','-v7.3');
    save([param.dtmatpath movieParam.fileName '_' param.infostr '_hof.mat'],'hofAll','-v7.3');
    save([param.dtmatpath movieParam.fileName '_' param.infostr '_hog.mat'],'hogAll','-v7.3');
    save([param.dtmatpath movieParam.fileName '_' param.infostr '_mbhx.mat'],'mbhxAll','-v7.3');
    save([param.dtmatpath movieParam.fileName '_' param.infostr '_mbhy.mat'],'mbhyAll','-v7.3');
    save([param.dtmatpath movieParam.fileName '_' param.infostr '_coord.mat'],'coordAll','-v7.3');
    
end

clear coordAll hofAll hogAll mbhxAll mbhyAll trajAll

%% run Fisher Vector on features
load(sprintf('%s/fv/%s/%s_pcaCoeff.mat',param.mbase,param.mstr,param.infostr));

for n = 1:length(param.fileIndx)
    
    movieParam = paramAll(param.dpath,param.fileIndx(n));
    fprintf('processing sample: %s\n', movieParam.fileName);
    
    for ii = 1:length(param.fv.featstr)
        fvparam = param.fv;
        fvparam.featstr = param.fv.featstr{ii};
        fvparam.namestr = [param.infostr '_' fvparam.featstr];
        fvparam.lfeat = param.fv.featlen(ii);
        fprintf('%s...\n',fvparam.featstr);
        eval(sprintf('%sFV = encodeIndivSpFV2(param.fileIndx(n),param.dtmatpath,fvparam);',...
            fvparam.featstr));
    end
    
    % put together FV, do pca
    FVall = [hofFV,hogFV,mbhxFV,mbhyFV]/4;
    muData = mean(FVall,1);
    drFVall = bsxfun(@minus,FVall,muData)*coeff;
    drFVall = drFVall(:,1:pcaDim);
    save([param.fvpath movieParam.fileName '_' param.infostr '_FVall.mat'],'FVall','-v7.3');
    save([param.fvpath movieParam.fileName '_' param.infostr '_drFVall.mat'],'drFVall','-v7.3');
    
end

clear FVall drFVall

%% generate SVM samples
for n = 1:length(param.fileIndx)
    
    movieParam = paramAll(param.dpath,param.fileIndx(n));
    sample = load([param.fvpath movieParam.fileName '_' param.infostr '_drFVall.mat']);
    sample = sample.drFVall;
    label = zeros(size(sample,1),1);

    % write to libsvm format file
    gnLibsvmFile(label,sample,[param.svmpath param.svm.name '_' movieParam.fileName '.txt']);

end

%% SVM
num_file = length(param.fileIndx);
fnames = '';
for n = 1:num_file
    fnames = [fnames sprintf('"%s" ',fileinfo(param.fileIndx(n)))];
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
for n = 1:num_file
    fname = fileinfo(param.fileIndx(n));
    [pred,pred_score] = saveSVMpred(param.svmpath,...
        [param.svm.name '_' fileinfo(param.fileIndx(n))]);
    save([param.svmpath fname '_annotype' num2str(param.annotype) ...
        '_pred_results.mat'],'pred','pred_score','-v7.3');
end




