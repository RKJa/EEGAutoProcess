function [W,S] = beamica(X,P,W0,S,mu,max_iter,lrate,tradeoff,verbose,usegpu,convergence_check)
% function [W,S] = beamica(X,B,W,S,mu,max_iter,lrate)
% Perform Beamforming-informed Infomax ICA.
%
% In:
%   X : data matrix, [#channels x #samples]
%
%   P : optional cell array of per-component beamformer penalty matrices where 
%       P{k} = (I-Uk*inv(Uk'*Uk)*Uk'), Uk = S*Fk, Fk=[Nx3] matrix of 3-axis forward
%       projection maps from desired source location for the k'th component (default: {})
%
%   W : optionally the initial unmixing matrix (default: eye(C))
%
%   S : optionally the initial sphering matrix (default: pinv(sqrtm(cov(X'))))
%
%   mu : optionally the initial mean vector (default: mean(X,2)
%
%   max_iter : optionally the maximum number of iterations (default: 750)
%
%   lrate : optionally the learning rate (default: 0.5)
%
%   tradeoff : optionally tradeoff parameter for beam penalty vs. infomax
%              (0-1, default: 0.5 -- larger means preference towards BP)
%
%   verbose : display progress output (default: true)
%
%   usegpu : try to run computation on the GPU (default: true)
%
%   convergence_check : force check for convergence on GPU (slower, default: false)
%
% Out:
%   W : final unmixing matrix
%
%   S : final sphering matrix
%
%                            Christian Kothe, Swartz Center for Computational Neuroscience, UCSD
%                            2013-07-29
%
%                            Based on Jason Palmer's minimal extended Infomax code extica.m


% turn into continuous data
X = X(:,:);
[C,N] = size(X);

% get arguments
if nargin < 11 || isempty(convergence_check)
    convergence_check = false; end
if nargin < 10 || isempty(usegpu)
    usegpu = true; end
if nargin < 9 || isempty(verbose)
    verbose = true; end
if nargin < 8 || isempty(tradeoff)
    tradeoff = 0.5; end
if nargin < 7 || isempty(lrate)
    lrate = 0.5; end
if nargin < 6 || isempty(max_iter)
    max_iter = 750; end
if nargin < 5 || isempty(mu)
    mu = mean(X,2); end
if nargin < 4 || isempty(S)
    S = pinv(sqrtm(cov(X'))); end
if nargin < 3 || isempty(W0)
    W0 = eye(C); end
if nargin < 2 || isempty(P)
    P = {}; end

W = W0;
I = eye(C);
d = zeros(C);

% standardize the data
X = bsxfun(@minus,X,mu);
X = S*X;

% reformat the penalty tensor
nP = length(P);
P =  permute(cat(3,P{:}),[3 2 1]);

fprintf('Running Beamica on the for %i iterations.\n',max_iter);
if usegpu    
    try X = gpuArray(X); d = gpuArray(d); disp('Using the GPU.'); catch, end;  end

for iter = 1:max_iter
    if verbose
        fprintf('iter = %i/%i\n',iter,max_iter); end
    
    % get the sources
    y = W*X;
    
    % get the Infomax gradient
    t = y + tanh(y);
    B = (t*y')/N;

    % get the beam penalty gradient
    if nP        
        d(1:nP,:) = 2*sum(bsxfun(@times,permute(W(1:nP,:),[1 3 2]),P),3); end
    
    % natural gradient direction
    dW = (I - (tradeoff*d + (1-tradeoff)*B)) * W;
    
    % update W
    W = W + lrate*dW;
    
    % optional convergence check
    if (~usegpu || convergence_check) && any(~isfinite(W(:)))
        disp('Divergence; dividing lrate by 2.');
        W = W0;
        lrate = lrate/2;
    end
        
end

if isa(W,'gpuArray')
    W = gather(W);
    S = gather(S);
end
