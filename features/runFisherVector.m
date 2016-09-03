function [] = runFisherVector(param)

% parse input parameters
fileIndx = param.fileIndx;
K = param.K;
numPatch = param.numPatch;
filepath = param.filepath;
savepath = param.savepath;
intran = param.intran;
powern = param.powern;
infostr = param.infostr;
ci = param.ci;

%% HOF
fprintf('HOF...\n');

% fit GMM and encode FV
[coeff,w,mu,sigma,hofFV,eigval,~,acm] = encodeSpFV(fileIndx,K,9,numPatch,filepath,...
    [infostr '_hof'],intran,powern);

% save results
save([savepath infostr '_hofCoeff.mat'],'coeff','eigval','-v7.3');
save([savepath infostr '_hofFV.mat'],'hofFV','-v7.3');
save([savepath infostr '_hofGMM.mat'],'w','mu','sigma','-v7.3');

%% HOG
fprintf('HOG...\n');

% fit GMM and encode FV
[coeff,w,mu,sigma,hogFV,eigval] = encodeSpFV(fileIndx,K,8,numPatch,filepath,...
    [infostr '_hog'],intran,powern);

% save results
save([savepath infostr '_hogCoeff.mat'],'coeff','eigval','-v7.3');
save([savepath infostr '_hogFV.mat'],'hogFV','-v7.3');
save([savepath infostr '_hogGMM.mat'],'w','mu','sigma','-v7.3');

%% MBHx
fprintf('MBHx...\n');

% fit GMM and encode FV
[coeff,w,mu,sigma,mbhxFV,eigval] = encodeSpFV(fileIndx,K,8,numPatch,filepath,...
    [infostr '_mbhx'],intran,powern);

% save results
save([savepath infostr '_mbhxCoeff.mat'],'coeff','eigval','-v7.3');
save([savepath infostr '_mbhxFV.mat'],'mbhxFV','-v7.3');
save([savepath infostr '_mbhxGMM.mat'],'w','mu','sigma','-v7.3');

%% MBHy
fprintf('MBHy...\n');

% fit GMM and encode FV
[coeff,w,mu,sigma,mbhyFV,eigval] = encodeSpFV(fileIndx,K,8,numPatch,filepath,...
    [infostr '_mbhy'],intran,powern);

% save results
save([savepath infostr '_mbhyCoeff.mat'],'coeff','eigval','-v7.3');
save([savepath infostr '_mbhyFV.mat'],'mbhyFV','-v7.3');
save([savepath infostr '_mbhyGMM.mat'],'w','mu','sigma','-v7.3');

%% put together data, do pca
% FVall = [hofFV,hogFV]/2;
FVall = [hofFV,hogFV,mbhxFV,mbhyFV]/4;
save([savepath infostr '_FVall.mat'],'FVall','acm','-v7.3');

% pca
[drFVall,coeff] = drHist(FVall,ci);
pcaDim = size(drFVall,2);
save([savepath infostr '_drFVall.mat'],'drFVall','acm','-v7.3');
save([savepath infostr '_pcaCoeff.mat'],'coeff','pcaDim','-v7.3');


end