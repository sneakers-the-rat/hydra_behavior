function [centerHist] = getCenterHist(flows,flowInd,clusterInd,rawCenters,m,n,calcMeth)

% calculate histogram distribution of trajectory identities over centers in
% each time window
% INPUT:
%     flows: generated by function getFlows. Rows indicate
%         trajectories in the given time window, columns indicate time points;
%         the first column indicates the time window of the current
%         trajectory, the second column indicates the patch index, the rest
%         of the columns pairs up to give (dx,dy).
%     flowInd: generated by kmeans clustering. Each entry indicates the
%        cluster identity of the corresponding trajectory in allFlows.
%     calcMeth: method used for calculating histogram
%         - 'hard': direct histogram calculation
%         - 'kcb': kernel codebook encoding
%     rawCenters: centers generated by kmeans clustering. only used if
%         calMeth is 'kcb'
% OUTPUT:
%     centerHist: distribution histogram over the centers generated by
%         clustering

flow_sig = std(flows(:));
nz = abs(flows)>flow_sig;
flows = flows(sum(nz,2)~=0,:);
flowInd = flowInd(sum(nz,2)~=0,:);

nt = max(flowInd(:,1)); % number of time windows
ns = m*n; % number of patches
numCluster = size(rawCenters,1);
centerHist = zeros(nt,numCluster*m*n);
softnum = ceil(numCluster/20); % number of closest centers to take in the soft calculation method
%softnum = numCluster;

for i = 1:nt % go over all time windows
   %twInd = find(flowInd(:,1)==i); % calcualte histogram for each time window
   if ~isempty(find(flowInd(:,1)==i,1))
       %centerHist(i,:) = zeros(1,numCluster*ns);
       for j = 1:ns % calculate histogram for spatial each patch in the time window
           patchInd = find(flowInd(:,1)==i&flowInd(:,2)==j);
           if ~isempty(patchInd)
               switch calcMeth
                   case 'hard'
                       centerHist(i,(j-1)*numCluster+1:j*numCluster) = ...
                           histc(clusterInd(patchInd,:),1:numCluster)./...
                               sum(histc(clusterInd(patchInd,:),1:numCluster));
                           centerHist(i,:) = centerHist(i,:)./sum(centerHist(i,:));
                   case 'kcb_euc'
                       rawCentDist = pdist2(flows(patchInd,:),rawCenters);
                       [rawCentDist,keepInd] = sort(rawCentDist,2,'descend');
                       %rawHist = rawCentDist(:,1:softnum)./(sum(rawCentDist(:,1:softnum),2)*ones(1,softnum));
                       rawHist = zeros(1,numCluster);
                       for k = 1:size(rawCentDist,1)
                           rawHist(keepInd(k,1:softnum)) = rawHist(keepInd(k,1:softnum))+...
                               ((sum(rawCentDist(k,1:softnum),2)*ones(1,softnum)))...
                               ./rawCentDist(k,1:softnum);
                       end
                       centerHist(i,(j-1)*numCluster+1:j*numCluster) = ...
                           sum(rawHist,1)./sum(rawHist(:));
                       %centerHist(end,:) = centerHist(end,:)./sum(centerHist(end,:));
                   case 'kcb_exp'
                       rawCentDist = exp(pdist2(flows(patchInd,:),rawCenters)/2);
                       [rawCentDist,keepInd] = sort(rawCentDist,2,'descend');
                       %rawHist = rawCentDist./(sum(rawCentDist,2)*ones(1,numCluster));
                       rawHist = zeros(1,numCluster);
                       for k = 1:size(rawCentDist,1)
                           rawHist(keepInd(k,1:softnum)) = rawHist(keepInd(k,1:softnum))+...
                               (sum(rawCentDist(k,1:softnum),2)*ones(1,softnum))./rawCentDist(k,1:softnum);
                       end
                       centerHist(i,(j-1)*numCluster+1:j*numCluster) = ...
                           sum(rawHist,1)./sum(rawHist(:));
                       %centerHist(end,:) = centerHist(end,:)./sum(centerHist(end,:));  
                   case 'llc'
                       centerHist(i,(j-1)*numCluster+1:j*numCluster) = ...
                           sum(LLC_coding_appr(rawCenters,flows(patchInd,:),softnum),1);
                       centerHist(i,(j-1)*numCluster+1:j*numCluster) = ...
                           centerHist(i,(j-1)*numCluster+1:j*numCluster)./...
                           sum(centerHist(i,(j-1)*numCluster+1:j*numCluster));
                   otherwise
                       error('error in getCenterHist: calculation method invalid');
               end
           end
           
       end
       
   end
end



end