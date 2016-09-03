function [trackVelBatch,trackLocBatch] = extractTrackBatchSm(m,n,tw,movieParam,hydraParam)

% this version smooths the trajectories while extracting them from the raw
% file
% extract track information from spatial-temporal cubes with size a*b and
% time window tw from cvs file generated by trackmate
% normalize by centralizing all points to the centroid of hydra, and divide
% by the length of the hydra
%
% Input:
%     a: size of cube in x direction
%     b: size of cube in y direciton 
%     tw: time window of the cube
%     movieParam: struct generated by paramAll
%     hydraParam: struct generated by function estimateHydraParam
%
% Output:
%     trackVelBatch: a cell array that contains velocity vectors, 
%         each row represents one time window with cubes in a linearized
%         sequence. The element in each cell is a n*(tw*2+1) matrix, n
%         indicates the number of tracked cells in the cube; the first
%         column is the track ID, and (x,y) comes after the track ID for tw
%         frames.
%     trackLocBatch: a cell array that contains point locations, in the
%         same formate as above.


%% get parameters

% calculate the size of the final result
numCubes = floor((movieParam.numImages-1)/tw);

% import csv track file and get the number of all cells in all frames
%tracksRaw = csvread(movieParam.filenameTracks);
tracksRaw = dlmread(movieParam.filenameTracks,'\t',1,3);
numCells = max(tracksRaw(:,1));

% smoothe the trajectories
for i = 1:numCells
    cellInd = find(tracksRaw(:,1)==i);
    xx = tracksRaw(cellInd,3);
    yy = tracksRaw(cellInd,4);
    [smxx,smyy] = smoothTraj(xx,yy);
    tracksRaw(cellInd,3) = smxx;
    tracksRaw(cellInd,4) = smyy;
end

% put all tracks together
tracksAll = cell(movieParam.numImages,1);
scale = hydraParam.length/200; % normalizing parameter
for i = 1:movieParam.numImages
    ind = (tracksRaw(:,7)==i-1); % because in the csv file frame starts from 0
    infomat = zeros(sum(ind),3);
    infomat(:,1) = tracksRaw(ind,1); % track ID
    coordCurrent = tracksRaw(ind,3:4);
    % rotate to calibrated coordinate system (animal axis aligned) and
    % centralize the centroid
    coordNew = (coordCurrent-ones(sum(ind),1)*hydraParam.centroid)*...
        hydraParam.rotmat;
    % normalize by half length of the hydra, and scale up by 100
    coordNew = coordNew./scale;
    infomat(:,2:3) = coordNew; % (x,y) location
    tracksAll{i} = infomat;
    clear infomat
    clear ind
end

clear tracksRaw


%% calculate parameters in the normalized coordinate system
a = floor(hydraParam.length/(scale*m));
b = floor(hydraParam.length/(scale*n));
a0 = m*a/2;
b0 = n*b/2;

%% sort cubes

% initialization, final result will be stored in a cell array
trackVelBatch = cell(numCubes,m*n);
trackLocBatch = cell(numCubes,m*n);

indt = 1; % index of time window
count = 1; % counting within the time window
for i = 2:tw*numCubes+1 % neglect incomplete time window
    
    infomat = tracksAll{i};
    
    % go through all the tracked cells in current frame
    for j = 1:size(infomat,1)
        
        % get current coordinate and id, store them
        coord = infomat(j,2:3);
        id = infomat(j,1);
        
        % determine where it belongs to in the linearized cell array of
        % current time window
        %inds = floor(coord(2)/round(movieParam.imageSize(2)/n))*...
        %    dimBatch(1)+ceil(coord(1)/round(movieParam.imageSize(1)/m)); % index of cube in the current time window
        if coord(1) <= -a0
            tmp1 = 1;
        elseif coord(1) > a0
            tmp1 = m;
        else
            tmp1 = ceil((coord(1)+a0)/a);
        end
        if coord(2) <= -b0
            tmp2 = 0;
        elseif coord(2) > b0
            tmp2 = (n-1)*m;
        else
            tmp2 = floor((coord(2)+b0)/b)*m;
        end
        inds = tmp1+tmp2;
        
        if tmp2==0
            i;
        end
        
        % take out the matrices for modification
        velmat = trackVelBatch{indt,inds};
        locmat = trackLocBatch{indt,inds};
        
        % if previous information unavailable
        if isempty(velmat)
            
            infomatPrev = tracksAll{i-1};
            indPrev = find(infomatPrev(:,1)==infomat(j,1));
                
            % if previous spot exists, calculate velocity
            if ~isempty(indPrev)
                velmat(1,1) = infomat(j,1);
                velmat(1,count*2:count*2+1) = infomat(j,2:3)-infomatPrev(indPrev,2:3);
                locmat(1,1) = infomat(j,1);
                locmat(1,count*2:count*2+1) = infomat(j,2:3);
            else % otherwise ignore this round
                continue;
            end
                
        else
                
            % get index
            indtmp = find(velmat(:,1)==id);
            
            % search for the location in previous frame
            infomatPrev = tracksAll{i-1};
            indPrev = find(infomatPrev(:,1)==infomat(j,1));
            
            if ~isempty(indPrev) % if the cell is tracked
                if ~isempty(indtmp)
                    velmat(indtmp,2*count:2*count+1) = infomat(j,2:3)-infomatPrev(indPrev,2:3); 
                    locmat(indtmp,2*count:2*count+1) = infomat(j,2:3);
                else % otherwise ignore this round
                    velmat(end+1,1) = id;
                    velmat(end,2*count:2*count+1) = infomat(j,2:3)-infomatPrev(indPrev,2:3); 
                    locmat(end+1,1) = id;
                    locmat(end,2*count:2*count+1) = infomat(j,2:3); 
                end
            else
                if ~isempty(indtmp) % fill in zeros for future convinience
                    velmat(indtmp,2*count:2*count+1) = zeros(1,2);
                    locmat(indtmp,2*count:2*count+1) = zeros(1,2);
                else
                    continue;
                end
            end
                
        end
        
        trackVelBatch{indt,inds} = velmat;
        trackLocBatch{indt,inds} = locmat;
        
    end
    
    count = count+1;
    
    if count > tw % this time window is finished
        
        % go through all batches and fill in zeros
        for j = 1:m*n
            velmat = trackVelBatch{indt,j};
            locmat = trackLocBatch{indt,j};
            if ~isempty(velmat)
                if size(velmat,2)<2*tw+1
                    velmat(:,end:2*tw+1) = 0;
                    locmat(:,end:2*tw+1) = 0;
                end
                velmat = velmat(:,2:2*tw+1);
                locmat = locmat(:,2:2*tw+1);
                trackVelBatch{indt,j} = velmat;
                trackLocBatch{indt,j} = locmat;
            end
        end
        
        indt = indt+1;
        count = 1;
    end
    
    
end



end