classdef ParadigmSIFT < ParadigmDataflowSimplified
    % Source Information Toolbox adapter paradigm.
    %
    % This paradigm exposes SIFT-derived connectivity features within BCILAB.
    %
    % Name:
    %   Source Information Flow Toolbox Adapter
    %
    
    
    methods
      
        function defaults = preprocessing_defaults(self)
            % define the default pre-processing parameters of this paradigm
            defaults = { ...
                'Resampling',128, ...
                'DataCleaning',{...                    
                    'DataSetting',{'drycap' ...
                        'DriftCutoff',[0.1 1], ...
                        'BadSubspaceRemoval',{ ...
                            'StandardDevCutoff',4, ...
                            'ProcessingDelay',0.125}, ...
                     }, ...
                    'HaveChannelDropouts',false, ...
                    'RetainPhases',false}, ...
                'Rereferencing','on', ...
                'SourceLocalization', {...
                    'InverseMethod', { ...
                        'LORETA', ...
                        'LoretaOptions',{...
                            'MaxIterations',50,...
                            'BlockSize',32,...
                            'SkipFactor',0}}, ....
                    'SourceAtlasROI',{'Precentral_L' 'Precentral_R' 'Frontal_Sup_L' 'Frontal_Sup_R' 'Frontal_Sup_Orb_L' 'Frontal_Sup_Orb_R' 'Frontal_Mid_L' 'Frontal_Mid_R' 'Frontal_Mid_Orb_L' 'Frontal_Mid_Orb_R' 'Frontal_Inf_Oper_L' 'Frontal_Inf_Oper_R' 'Frontal_Inf_Tri_L' 'Frontal_Inf_Tri_R' 'Frontal_Inf_Orb_L' 'Frontal_Inf_Orb_R' 'Rolandic_Oper_L' 'Rolandic_Oper_R' 'Supp_Motor_Area_L' 'Supp_Motor_Area_R' 'Olfactory_L' 'Olfactory_R' 'Frontal_Sup_Medial_L' 'Frontal_Sup_Medial_R' 'Frontal_Mid_Orb_L' 'Frontal_Mid_Orb_R' 'Rectus_L' 'Rectus_R' 'Insula_L' 'Insula_R' 'Cingulum_Ant_L' 'Cingulum_Ant_R' 'Cingulum_Mid_L' 'Cingulum_Mid_R' 'Cingulum_Post_L' 'Cingulum_Post_R' 'Hippocampus_L' 'Hippocampus_R' 'ParaHippocampal_L' 'ParaHippocampal_R' 'Amygdala_L' 'Amygdala_R' 'Calcarine_L' 'Calcarine_R' 'Cuneus_L' 'Cuneus_R' 'Lingual_L' 'Lingual_R' 'Occipital_Sup_L' 'Occipital_Sup_R' 'Occipital_Mid_L' 'Occipital_Mid_R' 'Occipital_Inf_L' 'Occipital_Inf_R' 'Fusiform_L' 'Fusiform_R' 'Postcentral_L' 'Postcentral_R' 'Parietal_Sup_L' 'Parietal_Sup_R' 'Parietal_Inf_L' 'Parietal_Inf_R' 'SupraMarginal_L' 'SupraMarginal_R' 'Angular_L' 'Angular_R' 'Precuneus_L' 'Precuneus_R' 'Paracentral_Lobule_L' 'Paracentral_Lobule_R' 'Heschl_L' 'Heschl_R' 'Temporal_Sup_L' 'Temporal_Sup_R' 'Temporal_Pole_Sup_L' 'Temporal_Pole_Sup_R' 'Temporal_Mid_L' 'Temporal_Mid_R' 'Temporal_Pole_Mid_L' 'Temporal_Pole_Mid_R' 'Temporal_Inf_L' 'Temporal_Inf_R'}, ...
                    'AtlasROI', {'Precentral_L' 'Precentral_R' 'Frontal_Sup_L' 'Frontal_Sup_R' 'Frontal_Mid_L' 'Frontal_Mid_R' 'Supp_Motor_Area_L' 'Supp_Motor_Area_R' 'Cingulum_Ant_L' 'Cingulum_Ant_R' 'Cingulum_Mid_L' 'Cingulum_Mid_R' 'Cingulum_Post_L' 'Cingulum_Post_R' 'Occipital_Mid_L' 'Occipital_Mid_R'}, ... 
                    'Verbosity',true}, ...
                'FIRFilter',{ ...
                    'Frequencies',[45 50], ...
                    'Type','minimum-phase', ...
                    'Mode','lowpass'},...
                'EpochExtraction',[-0.2 1]};
        end
        
        function defaults = machine_learning_defaults(self)
            defaults = {'logreg', ...
                        'Variant',{'lars', ...
                            'ElasticMixing',0.5, ...
                            'MinLambda',0.0001,...
                            'CustomLoss','auc'}};
        end
        
        function model = feature_adapt(self,varargin)
            % configure and adapt parameters for SIFT's online pipeline
            g = arg_define(varargin, ...
                    arg_norep('signal'), ...
                    arg_sub({'connPipeline','ConnectivityPipeline'},{'EEG',struct('srcpot',1,'icaweights',1), ...
                        'Preprocessing',{ ...
                            'VerbosityLevel',0,...
                            'SignalType','Sources', ...
                            'Detrend',{'DetrendingMethod',{'linear'}},...
                            'NormalizeData',{}}, ...
                        'Modeling',{ ...
                            'Segmentation VAR', ...
                                'Algorithm',{'Group Lasso (ADMM)', ...
                                    'WarmStart','on', ...
                                    'NormCols','norm', ...
                                    'ADMM_Options', {...
                                        'ReguParamLambda',search(2.^[-15:1.5:-3]), ...
                                        'Verbosity',false, ...
                                        'MaxIterations',150, ...
                                        'LambdaUpdate',false ...
                                        }}, ...
                            'Detrend','off', ...
                            'VerbosityLevel',0}, ...
                        'AutoSelectModelOrder',[], ...
                        'Connectivity', { ...
                            'ConnectivityMeasures',{'dDTF08','S'},...
                            'ConvertSpectrumToDecibels',true,...
                            'VerbosityLevel',0},...
                        'Validation',[] ...
                        },@onl_siftpipeline,'Connectivity extraction options.'), ...
                    arg_subtoggle({'lambdaSelection','RegularizationParameterSelection'},[], ...
                    { ...
                        arg_sub({'validationMetric','ValidationMetric'},...
                                {'plot',false, ...
                                 'verb',0, ...
                                 'checkConsistency',[],...
                                 'checkStability',[], ...
                                 'checkResidualVariance',{}, ...
                                 'checkWhiteness',[]}, ...
                                @est_validateMVAR,'Model validation options. Used for selection optimal lambda (VAR regularization).'), ...
                        arg({'lambdaGrid','LambdaGrid'},logspace(log10(1e-5),log10(100),10),[],'Lambda grid. This is a row vector of possible lambda values to search over','shape','row') ...
                    },'Options for selecting optimal lambda. This only applies if you are using regularized model fitting methods that accept a "lambda" parameter'), ...
                    arg({'valueFormat','ValueFormat'},'polar',{'complex','components','mixed','magnitude','sqrt-magnitude','log-magnitude','phase','polar'},'Output value format. Formatting for partially complex-valued features. Mixed means as-is, components means to separate real and imaginary components (both as real), magnitude retains only the complex magnitude, phase retains only the phase, and polar retains both magnitude and phase as real numbers.'), ...
                    arg({'featureShape','FeatureShape'},'[CCMxFT] (time/freq row sparsity matrix)',{'[CCFTMx1] (unstructured vector)','[CxCxFxTxM] (5d tensor)','[CCMxFT] (time/freq row sparsity matrix)','[CCxFTM] (per-link column sparsity matrix)','[CCxFT]_m1,..,[CCxFT]_mk (low-rank space/time structure, sparse methods)','[FxT]_c11,..,[FxT]_cnn (low-rank time/freq structure, sparse links)','[CxC]_ft1,..,[CxC]_ft2 (low-rank link structure, sparse time/freq)'},'Feature tensor arrangement. Features can be arranged in tensor or matrix or block-diagonal matrix form - most useful with the DAL classifier.'), ...
                    arg({'vectorizeFeatures','VectorizeFeatures'},true,[],'Vectorize feature tensors. This is for classifiers that cannot handle matrix or tensor-shaped features.'), ...
                    arg({'logBias','LogBias'},1e-4,[],'Bias for logarithms. This is to shift connectivity values to a Gaussian distribution and also to prevent negative infinities from occurring.'), ...
                    arg({'verb','Verbosity','verbosity'},true,[],'Verbose output'));
 
            if g.lambdaSelection.arg_selection ...
                    && g.lambdaSelection.validationMetric.checkWhiteness.arg_selection ...
                    && length(g.lambdaSelection.validationMetric.checkWhiteness.whitenessCriteria)>1
                error('BCILAB:ParadigmSIFT:MoreThanOneIC','Only one WhitenessCriteria can be selected for ParadigmSIFT.'); end
            
            if g.lambdaSelection.arg_selection ...
                 && sum([g.lambdaSelection.validationMetric.checkConsistency.arg_selection ...
                    g.lambdaSelection.validationMetric.checkResidualVariance.arg_selection ...
                    g.lambdaSelection.validationMetric.checkStability.arg_selection ...
                    g.lambdaSelection.validationMetric.checkWhiteness.arg_selection]) > 1
                error('BCILAB:ParadigmSIFT:MoreThanOneValidationMetric','Only one validation metric (Whiteness,Stability,ResidualVariance, or Consistency) may be selected for ParadigmSIFT'); end
                
            % force window length and step size to match epoch length
            model.siftPipelineConfig = g.connPipeline;
            
            continuous = self.make_continuous(g.signal);
            
            % lambda selection. 
            % Here we use one of validation metrics to select lambda
            if g.lambdaSelection.arg_selection
                if g.verb
                    fprintf('Performing grid search for optimal lambda\n'); end
                
                % fit model and perform validation
                connPipelineRange = g.connPipeline;
                if strcmpi(g.connPipeline.modeling.algorithm.arg_selection,'Group Lasso (ADMM)')
                    connPipelineRange.modeling.algorithm.admm_args.lambda = search(g.lambdaSelection.lambdaGrid);
                else
                    error('Unknown modeling method %s. Disable lambda search and try again',g.connPipeline.modeling.algorithm.arg_selection);
                    % FIXME: ADD ADDITIONAL CASES FOR OTHER ALGORITHMS...s
                end
                
                [min_idx,all_inputs,all_outputs] = utl_gridsearch('clauses',@onl_siftpipeline,connPipelineRange,'EEG',continuous,'connectivity',[],'validation',g.lambdaSelection.validationMetric); %#ok<ASGLU>
                
                % pick optimal lambda
                if g.lambdaSelection.validationMetric.checkConsistency.arg_selection
                    % objective function (minimize) is mean percent
                    % consistency over epochs
                    objFun = cellfun(@(x) x{1}.CAT.validation.PCstats.PC,all_outputs,'UniformOutput',false);
                    objFun = cellfun(@mean,objFun);
                elseif g.lambdaSelection.validationMetric.checkResidualVariance.arg_selection
                    % objective function (minimize) is residual whiteness
                    % over epochs
                    objFun = cellfun(@(x) x{1}.CAT.validation.residualstats.variance,all_outputs,'UniformOutput',false);
                    objFun = cellfun(@(x) mean(cell2mat(x)),objFun);
                elseif g.lambdaSelection.validationMetric.checkStability.arg_selection
                    % objective function (minimize) is fraction of epochs
                    % with unstable VAR model
                    objFun = cellfun(@(x) x{1}.CAT.validation.stabilitystats.stability,all_outputs,'UniformOutput',false);
                    objFun = 1-cellfun(@(x) nnz(x)/numel(x),objFun);
                elseif g.lambdaSelection.validationMetric.checkWhiteness.arg_selection
                    whitenessCriterion = lower(hlp_variableize(g.lambdaSelection.validationMetric.checkWhiteness.whitenessCriteria{1}));
                    % objective function (minimize) is 1-pvalue where
                    % a sufficiently large pvalue indicates white residuals
                    objFun = cellfun(@(x) x{1}.CAT.validation.whitestats.(whitenessCriterion).pval,all_outputs,'UniformOutput',false);
                    objFun = 1-cellfun(@mean,objFun);
                end
                
                % get the min of the objective function and select lambda
                [min_val min_idx] = min(objFun); %#ok<NCOMMA>
                optLambda = g.lambdaSelection.lambdaGrid(min_idx);
                if g.verb
                  fprintf('Optimal lambda found. lambda=%05g; objFun(lambda)=%0.5g\n',optLambda,min_val); end
                
                % retrieve the configuration structure corresponding to the
                % optimal lambda
                model.siftPipelineConfig.modeling = all_outputs{min_idx}{2}.modeling;
                if strcmpi(g.connPipeline.modeling.algorithm.arg_selection,'Group Lasso (ADMM)')
                    model.siftPipelineConfig.modeling.algorithm.admm_args.lambda = optLambda;
                end
            end
            model.valueFormat = g.valueFormat;
            model.featureShape = g.featureShape;
            model.vectorizeFeatures = g.vectorizeFeatures;
            model.logBias = g.logBias;
            model.args = g;
            
            % run feature extraction for a short signal to get shape information
            [print_output,tmpsignal] = evalc('pop_select(g.signal,''trial'',1:min(3,g.signal.trials))'); %#ok<ASGLU>
            if ~strcmp(g.featureShape,'[CCFTMx1] (unstructured vector)')                
                [dummy,model.shape] = self.feature_extract(tmpsignal,model); end %#ok<ASGLU>
        end
        
        function [features,shape] = feature_extract(self,signal,featuremodel)            
            % pre-calculate the placement indices within each epoch
            winStartIdx = 1 : round(featuremodel.siftPipelineConfig.modeling.winstep*signal.srate) : signal.pnts - ceil(featuremodel.siftPipelineConfig.modeling.winlen * signal.srate);
            % calculate placement indices across all epochs (after make_continuous)
            winStartIdx = 1 + bsxfun(@plus,winStartIdx'-1, (0:signal.trials-1)*signal.pnts);
            featuremodel.siftPipelineConfig.modeling.winStartIdx = winStartIdx(:);
            
            % extract connectivity features per epoch
            if onl_isonline
                EEG = onl_siftpipeline(featuremodel.siftPipelineConfig,'EEG',self.make_continuous(signal),'arg_direct',true);
            else
                hlp_microcache('conn','max_key_size',2^30,'max_result_size',2^30);
                EEG = hlp_microcache('conn',@onl_siftpipeline,featuremodel.siftPipelineConfig,'EEG',self.make_continuous(signal),'arg_direct',true);
            end
            
            rawfeatures = cellfun(@(connmethod) EEG.CAT.Conn.(connmethod), ...
                featuremodel.siftPipelineConfig.connectivity.connmethods, ...
                'UniformOutput',false);
            
            % reshape them to separate time points from trials {CxCxFxTxN, CxCxFxTxN, ...}
            for m=1:length(rawfeatures)
                [C,C2,F,TN] = size(rawfeatures{m});
                rawfeatures{m} = reshape(rawfeatures{m},C,C2,F,[],signal.trials);
            end
            
            % combine into single tensor: CxCxFxTxMxN
            features = permute(cat(6,rawfeatures{:}),[1,2,3,4,6,5]);
            [C,C2,F,T,M,N] = size(features);
            if C2 ~= C || N ~= signal.trials
                error('Unexpected feature shape.'); end
            
            % reshape into desired form (note: all arrays are implicitly xN)
            same_size = @(shape,features) isequal(shape(1:ndims(features)),size(features));
            switch featuremodel.featureShape                
                case '[CxCxFxTxM] (5d tensor)'
                    shape = [C,C,F,T,M];
                    if ~same_size([shape N],features)
                        error('Unexpected feature shape.'); end
                case '[CCMxFT] (time/freq row sparsity matrix)'
                    features = reshape(permute(features,[1 2 5 3 4 6]),[C*C*M,F*T,N]);
                    shape = [C*C*M,F*T];
                    if ~same_size([shape N],features)
                        error('Unexpected feature shape.'); end
                case '[CCxFTM] (per-link column sparsity matrix)'
                    features = reshape(permute(features,[1 2 3 4 5 6]),[C*C,F*T*M,N]);
                    shape = [C*C,F*T*M];
                    if ~same_size([shape N],features)
                        error('Unexpected feature shape.'); end
                case '[CCxFT]_m1,..,[CCxFT]_mk (low-rank space/time structure, sparse methods)'
                    features = reshape(permute(features,[1 2 3 4 5 6]),[C*C,F*T*M,N]);
                    shape = repmat([C*C,F*T],M,1);
                case '[FxT]_c11,..,[FxT]_cnn (low-rank time/freq structure, sparse links)'
                    features = reshape(permute(features,[3 4 1 2 5 6]),[F*T,C*C*M,N]);
                    shape = repmat([F,T],C*C*M,1);
                case '[CxC]_ft1,..,[CxC]_ft2 (low-rank link structure, sparse time/freq)'
                    features = reshape(permute(features,[1 2 3 4 5 6]),[C*C,F*T*M,N]);
                    shape = repmat([C,C],F*T*M,1);
                case '[CCFTMx1] (unstructured vector)'
                    shape = [C*C*F*T*M,1];
                otherwise
                    error('Unrecognized FeatureShape selected.');
            end
            
            % apply value formatting
            switch featuremodel.valueFormat
                case 'complex'
                    features = complex(features);
                case 'mixed'
                    % nothing to do
                case 'magnitude'
                    features = abs(features);
                case 'sqrt-magnitude'
                    features = sqrt(abs(features));
                case 'log-magnitude'
                    features = log(featuremodel.logBias+abs(features));
                case 'phase'
                    features = angle(features);
                    % these two cases will double the first shape parameter for each block
                case 'components'
                    % components are expanded along the first dimension
                    features = permute(cat(ndims(features)+1,real(features),imag(features)),[ndims(features)+1,1:ndims(features)]);
                    shape(:,1) = shape(:,1)*2;
                case 'polar'
                    % components are expanded along the first dimension
                    features = permute(cat(ndims(features)+1,abs(features),angle(features)),[ndims(features)+1,1:ndims(features)]);
                    shape(:,1) = shape(:,1)*2;
                otherwise
                    error(['Unsupported value format: ' featuremodel.valueFormat]);
            end
            
            % do final vectorization if desired
            if featuremodel.vectorizeFeatures
                features = reshape(features,[],signal.trials)'; end
        end
        
        function visualize_model(self,parent,featuremodel,predictivemodel,varargin) %#ok<*INUSD>
            hlp_varargin2struct(varargin,'signed',true,'reordering',[],'smoothing_kernel',[]);
            reordering= [1 2 4 8 5 6 3 7 9];
            global weights;
            global weights_ord;
            fs = featuremodel.shape;
            % get weights and featureshape
            w = predictivemodel.model.w; 
            if numel(w) == prod(fs)+1
                w = w(1:end-1); end
            % reshape into tensor            
            M = ((reshape(w,fs))); 
            % reverse frequency axis for plotting
            M = M(:,:,end:-1:1,:); 
            if ~isempty(smoothing_kernel)
                M = filter(smoothing_kernel/norm(smoothing_kernel),1,M,[],3);
                M = filter(smoothing_kernel/norm(smoothing_kernel),1,M,[],4);
            end
            weights = M;
            M = M(reordering,reordering,:,:);
            weights_ord = M;
            % add padding
            M(:,:,end+1,:)=max(abs(M(:)));
            M(:,:,:,end+1)=max(abs(M(:)));            
            % reorder for plotting
            N = reshape(permute(M,[3,1,4,2,5]),fs(1)*(fs(3)+1),fs(2)*(fs(4)+1),[]);
            % plot
            chns = featuremodel.siftPipelineConfig.channels;
            if signed
                imagesc(N,'XData',[0.5 length(chns)+0.5],'YData',[0.5 length(chns)+0.5]);
                caxis([-max(abs(N(:))) max(abs(N(:)))])
            else
                imagesc(abs(N),'XData',[0.5 length(chns)+0.5],'YData',[0.5 length(chns)+0.5]);
            end
            colorbar;
            title('Absolute model weights across component pairs in time/frequency.');            
            xlabel('From Component');
            set(gca,'XTick',1:length(chns),'XTickLabel',chns);
            set(gca,'YTick',1:length(chns),'YTickLabel',chns);
            ylabel('To Component');
        end

        function layout = dialog_layout_defaults(self)
            % define the default configuration dialog layout 
            layout = {'SignalProcessing.Resampling.SamplingRate', ...
                '', ...
                'SignalProcessing.DataCleaning.DataSetting', ...
                '', ...
                'SignalProcessing.SourceLocalization.InverseMethod', ...
                '', ...
                'SignalProcessing.SourceLocalization.AtlasROI', ...
                '', ...
                'SignalProcessing.EpochExtraction', ...
                '', ...
                'Prediction.FeatureExtraction.ConnectivityPipeline.Modeling.Algorithm.arg_selection', ...
                '', ...
                'Prediction.FeatureExtraction.ConnectivityPipeline.Connectivity.ConnectivityMeasures', ...
                'Prediction.FeatureExtraction.RegularizationParameterSelection.LambdaGrid', ...
                '',...
                'Prediction.FeatureExtraction.ValueFormat', ...
                'Prediction.FeatureExtraction.VectorizeFeatures', ...
                '', ...
                'Prediction.MachineLearning.Learner'};
        end
                
        function tf = needs_voting(self)
            % standard CSP requires voting to handle more than 2 classes
            tf = true; 
        end
        
        function sig = make_continuous(self,sig)
            % turn an epoched signal into a continuous one
            if sig.trials ~= 1
                % epoched dataset... reshape it
                sig.data = sig.data(:,:);
                if isfield(sig,'srcpot') && ~isempty(sig.srcpot)
                    sig.srcpot = sig.srcpot(:,:); end
                if isfield(sig,'icaact') && ~isempty(sig.icaact)
                    sig.icaact = sig.icaact(:,:); end
                [sig.chns,sig.pnts,sig.trials] = size(sig.data);
                sig.epoch = [];
                sig.event = [];
            end
        end
        
    end
end

