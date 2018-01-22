function [signal, state] = flt_loreta(varargin)
% Return the current source density for a given head model and data using
% the cortically-constrained standardized LORETA (low resolution electrical
% tomographic analysis) with a Bayesian update scheme for hyperparameters.
% The reconstructed CSD time-series (or source potential maps) will be 
% stored in signal.srcpot. This matrix has dimension [num_voxels x num_samples].
% 
% Note: 
%   This function is experimental an the behavior during online processing may depend on the chunk
%   size (and may be erratic for very small chunks).
%
% Author: Tim Mullen, Jan 2013, SCCN/INC/UCSD
%         Alejandro Ojeda, Jan 2013, SCCN/INC/UCSD
%         Christian Kothe, Jan 2013, SCCN/INC/UCSD


if ~exp_beginfun('filter'), return; end

declare_properties('name','LORETA', 'experimental',true, 'independent_channels',false, 'independent_trials',false);

arg_define(varargin, ...
    arg_norep({'signal','Signal'}), ...
    arg_nogui({'K','ForwardModel'},[],[],'Forward model (matrix)','shape','matrix'), ...
    arg_nogui({'L','LaplacianOperator'},[],[],'Laplacian operator. This is also known as the "precision matrix"'), ...
    arg_sub({'options','LoretaOptions'},{},...
        { ...
        arg({'maxTol','MaxTolerance'},1e-3,[0 Inf],'Tolerance for hyperparameter update loop','cat','Loreta Options'), ...
        arg({'maxIter','MaxIterations'},100,[1 Inf],'Maximum iterations for hyperparameter update loop','cat','Loreta Options'), ...
        arg({'gridSize','GridSize'},100,[1 Inf],'Lambda grid size.'), ...
        arg({'history','TrackHistory'},false,[],'Track history for hyperparameters'), ...
        arg({'verbose','VerboseOutput'},false,[],'Verbosity','cat','Loreta Options'), ...
        arg({'initNoiseFactor','InitialNoiseFactor'},0.001,[0 Inf],'Fraction of noise level. Used for initializing alpha parameter','cat','Loreta Options') ...
        arg({'block_size','BlockSize'},5, [], 'Block granularity for processing. The inverse operator will be updated using blocks of this many samples. This assumes that the inverse solution is spatially stationary over this many samples.'), ...
        arg({'skipFactor','SkipFactor'},0,[0 Inf],'Number of blocks to skip'), ...
        arg({'maxblocks','MaxBlocks'},Inf,[0 Inf],'Maximum number of blocks'), ...
        arg({'standardize','Standardize'},'all',{'none','channels','all'},'Rescale data to unit variance. If ''channels'', standardization is carried out across channels for each time point. If ''all'' each data sample is normalized by the standard deviation taken over all data.'), ...
        },'Additional options for Loreta function'), ...
    arg({'verb','Verbosity'},false,[],'Verbose output'), ...
    arg_nogui({'state','State'},[],[],'State object. When provided, hyperparameters will be estimated adaptively from prior state'));

if verb
    fprintf('Estimating current source density using cLORETA (%s)\n',mfilename); 
end

[nchs npnts] = size(signal.data);
if isempty(options.block_size) || options.block_size > npnts
    options.block_size = npnts;
end
numsplits    = floor(npnts/options.block_size);

% if necessary, cast to double-precision
if ~strcmpi(class(signal.data),'double')
    signal.data = double(signal.data);
end
    
% standardize the data
if ~strcmpi(options.standardize,'none')
    switch options.standardize
        case 'channels'
            scale = std(signal.data,[],1);
        case 'time'
            scale = std(signal.data,[],2);
        case 'all'
            scale = std(signal.data(:));
    end
    data = bsxfun(@rdivide,signal.data,scale);
%     scale = std(signal.data(:));
%     signal.data = signal.data./scale;
else
    data = signal.data;
end

if isempty(state) || ~isfield(state,'iLV') || isempty(state.iLV)
    if verb
        fprintf('...computing SVD of LFM.\n');
    end
    % mode is offline or we are initializing online filter
    % perform one-time SVD for faster computation.
    [U,S,V] = svd(K/L,'econ');
    state.iLV   = L\V;
    state.s2    = diag(S).^2; %s^2
    state.Ut    = U';
    state.alpha = [];
    state.beta  = [];
end

if npnts == 0
    % no data
    signal.srcpot    = [];
    state.srcweights = [];
    return;
end

signal.srcpot    = zeros([size(K,2) npnts]);
state.srcweights = zeros(size(L,1),nchs);
sum_srcweights   = zeros(size(L,1),nchs);
signal.loretaHistory = struct([]);

if verb
    fprintf('...assuming %d stationary blocks of length %d\n',numsplits,options.block_size);
end

k = 0;
% loop over sub-blocks and estimate CSD for each block
for i=0:options.skipFactor+1:numsplits-1
    if verb
        if i+1 >= floor(numsplits*(k+1)/10)
            k = k + 1;
            fprintf('%0.3g%%...',round((i/numsplits)*100));
        end
    end
    range = 1+floor(i*npnts/numsplits) : min(npnts,floor((i+1)*npnts/numsplits));
    % call (bayesian) loreta estimator
    [signal.srcpot(:,range), state.alpha, state.beta, state.srcweights tmpHist] ...
        = dynamicLoreta(state.Ut, data(:,range), state.s2, state.iLV, L, options, state.alpha, state.beta);
    if ~isempty(tmpHist)
        signal.loretaHistory = [signal.loretaHistory,tmpHist]; end
    % running sum
    sum_srcweights = sum_srcweights + state.srcweights;
    
    if options.skipFactor > 0
        % estimate CSD for samples between blocks using current inverse operator
        range = 1+floor((i+1)*npnts/numsplits) : min(npnts,floor((i+options.skipFactor+1)*npnts/numsplits));
        signal.srcpot(:,range) = state.srcweights*data(:,range);
    end
    
    if (numsplits-1) >= options.maxblocks
        break;
    end
end

if numsplits > 1
    % store the mean inverse operator over all splits          
    state.srcweights = sum_srcweights/ceil(numsplits/(options.skipFactor+1));
end

if (numsplits-1) >= options.maxblocks
    % if we have remaining blocks, filter remaining data
    % using the mean inverse operator
    signal.srcpot(:,range(end)+1:end) = state.srcweights*data(:,range(end)+1:end);
end

if ~strcmpi(options.standardize,'none')
    % recale data to original units
%     signal.srcpot     = signal.srcpot*scale;
%     state.srcweights  = state.srcweights/scale;
    signal.srcpot = bsxfun(@times,signal.srcpot,scale);
%     signal.srcpot = bsxfun(@rdivide,signal.srcpot,std(signal.srcpot,[],1));
%     state.srcweights  = bsxfun(@times,state.srcweights,scale'); %state.srcweights/mean(scale);
end

if verb
    fprintf('done.\n');
end
    
%% DEBUG: HACK
% signal.data = origdata;
%%
exp_endfun;
