% This should be run after MergeEEG (if you are joining files).

% Any issues Rajat_Jain@IEEE.org
origfilepath='F:\NoBCIpilot\processed'; %Folder where all the data is stored
replacefilepath='F:\NoBCIpilot\ERPStats';
filetype='.set'; %Ending- all raw data should be labelled ending from 1 up to 9. The _processed is output from FilterEpochEEG

PhotoDiodeEventCheck=0; %Convert and check each point with photodiode points
Run_ERSP=false;
Run_PhaseLocking=false;

PhaseLockingchannels={}; % Only calculate "PhaseLocking" in select channels - leave empty to keep all

Run_Coherence=false;
%exptypes={'IMPULSE', 'SUSTAINED'}; %This should be the same length as allevents

%allevents={{{'32'},{'128'}}, {{'32'},{'128'}}};

%eventnames={{'Targets','Non-Targets'}, {'Targets','Non-Targets'}};


% %Impulse
% exptypes{1}='IMPULSE';
% allevents{1}={{'32'},{'128'}}; 
% eventnames{1}={'Targets','Non-Targets'};
% 
% % Sustained
% exptypes{2}='SUSTAINED';
% allevents{2}={{'32'},{'128'}}; 
% eventnames{2}={'Targets','Non-Targets'};

% cBCI
exptypes={'_'};
allevents={{{'Cue'}}};
eventnames={{'Cue'}};
%% Load in BCILAB
if matlabpool('size')< feature('numCores')
    if matlabpool('size')>0
        matlabpool('close');
    end
    matlabpool('open','local',feature('numCores'));
end

run(['../../SIFT/StartSIFT.m']); %Start SIFT
run(['../bcilab']); %Start BCIlab
pop_editoptions( 'option_single', false);
%% Now let's Process!

fileList = getAllFiles(origfilepath);
Fileidx=strfind(fileList,filetype); Fileidx=find(~cellfun(@isempty,Fileidx)); %Find the cleaned set Files
fileList=fileList(Fileidx); %Extract just these files

for fn=1:length(fileList)
    try
        pathsep=strfind(fileList{fn},filesep);pathsep=pathsep(end); %find where the directory ends and filename starts
        filename=fileList{fn}(pathsep+1:end-length(filetype));
        
        %IDENTIFY WHICH EXPERIMENT TYPE THIS FILE IS
        vin=zeros(length(exptypes),1);
        for v=1:length(vin)
            vin(v)=~isempty(strfind(lower(filename),lower(exptypes{v})));
        end
        if isempty(find(vin))
            disp(['Experiment type not found! Cannot Process ERPS for ' filename])
        else
            idx=find(vin);ide=idx(1);
            
            filepath=fileList{fn}(1:pathsep);
            newfilepath=strrep(filepath, origfilepath, replacefilepath);
            if ~exist(newfilepath,'dir');
                mkdir(newfilepath);
            end
            
            for eco=1:length(allevents{ide})
                events=allevents{ide}{eco}; %Pick according to experiment type, and then event type
                ERP=struct;
                EEG=pop_loadset([filename filetype],filepath);
                if PhotoDiodeEventCheck %We can check event types into list of photodiodes which are switched on
                    neweventlist=[];
                    for evno=1:length(EEG.epoch)
                        epoch_point=cell2mat(EEG.epoch(evno).eventlatency)==0; %Find where in the epoch the event actually occured
                        currentevent=str2double(EEG.epoch(evno).eventtype{epoch_point});
                        if ~isnan(currentevent)
                            currentevent=dec2bin(currentevent,16); %Take event and convert to binary input list
                            newevent=[0,0,0,0];
                            for pdcount=1:length(newevent)
                                if strcmp(currentevent(pdcount),'1')
                                    newevent(pdcount)=1; %newevent is a list which inputs are on
                                end
                            end
                            for evref=1:length(events)
                                validevent=1; %Assume its a valid event and reject if not
                                for eventelement=1:length(events{evref})
                                    if events{evref}(eventelement)~=-1 && events{evref}(eventelement)~=newevent(eventelement)
                                        validevent=0;
                                    end
                                end
                                if validevent==1
                                    neweventlist(end+1)=evno;
                                end
                            end
                        end
                    end
                    neweventlist=unique(neweventlist);
                    % Now find the events that are actually in the epoch
                    ERP.data=mean(EEG.data(:,:,neweventlist),3);
                    
                    
                else
                    memevents=ismember({EEG.event.type},events);
                    event_epochs=[EEG.event.epoch];
                    neweventlist=event_epochs(memevents);
                    ERP.data=mean(EEG.data(:,:,neweventlist),3);
                    ERP.numtrials=length(neweventlist);
                    
                end
                if ~exist([newfilepath filename '_' eventnames{ide}{eco} '_ERPs.mat'],'file');
                    
                    %ERP.data=mean(EEG.data,3); %Average across trials so this is electrodes x timepoints
                    [ERP.P1amp, ERP.P1lat] = fPickPeakWin(ERP.data,EEG.times,[70 130],'max',5);
                    [ERP.N1amp, ERP.N1lat] = fPickPeakWin(ERP.data,EEG.times,[140 220],'min',5);
                    [ERP.P300amp, ERP.P300lat] = fPickPeakWin(ERP.data,EEG.times,[250 550],'max',5);
                    ERP.chanlocs=EEG.chanlocs;
                    ERP.channels={ERP.chanlocs.labels};
                    ERP.times=EEG.times;
                    save([newfilepath filename '_' eventnames{ide}{eco} '_ERPs.mat'],'ERP');
                end
                %% ERSP section
                if Run_ERSP==true
                    try
                        if ~exist([newfilepath filename '_' eventnames{ide}{eco} '_ERSP.mat'],'file')
                            frames=size(EEG.data,2);
                            tlimits=[EEG.times(1), EEG.times(end)];
                            ERSPs=struct('data',[],'itc',[],'powbase',[],'times',[],'freqs',[],'itcphase',[]);
                            ERSPs(size(EEG.data,1)).data=[];
                            AllCurrentData=EEG.data(:,:,neweventlist);
                            parfor elec=1:size(EEG.data,1)
                                disp(['Now Processing Electrode ' num2str(elec)]);
                                data=AllCurrentData(elec,:,:);data=data(:)';
                                [ERSPs(elec).data,ERSPs(elec).itc,ERSPs(elec).powbase,ERSPs(elec).times,ERSPs(elec).freqs,~,~,ERSPs(elec).itcphase]=newtimef(data,frames,tlimits,EEG.srate,1,'timesout',400,'maxfreq',40,'baseline',-700,'plotersp','off','plotitc','off','freqscale','log');

                            end
                            
                            ERSP=ERSPs(1);
                            ERSP.chanlocs=EEG.chanlocs;
                            ERSP.channels={ERSP.chanlocs.labels};
                            flds={'data','itc','powbase','itcphase'};
                            for fc=1:length(flds)
                                ERSP.(flds{fc})=zeros([length(ERSPs) size(ERSP.(flds{fc}))]);
                                
                                for elec=1:length(ERSPs)
                                    ERSP.(flds{fc})(elec,:,:,:,:)=ERSPs(elec).(flds{fc});
                                end
                            end
                            
                            save([newfilepath filename '_' eventnames{ide}{eco} '_ERSP.mat'],'ERSP');
                            clear ERSP;
                        end
                    catch err
                        disp(['ERSP processing failed: ' filename]);
                        warning(err.message)
                    end
                end
                
                %% PhaseLocking Section
                if Run_PhaseLocking==true
                    try
                        if ~exist([newfilepath filename '_' eventnames{ide}{eco} '_PhaseLocking.mat'],'file')
                            
                            if ~isempty(PhaseLockingchannels)
                                EEGPL=exp_eval(flt_selchans(EEGPL,PhaseLockingchannels));
                            end
                            newdata=EEGPL.data(:,:,neweventlist); %Electrode x time x trials
                            
                            % First break down into Morlets
                            Morlets=cell(size(newdata,1),1);
                            for el=1:length(Morlets)
                                Morlets{el}=angle(fMorletWavelet(squeeze(newdata(el,:,:)),EEGPL.srate,[4:20],ones(17,1)));
                            end
                            
                            % Now contruct PhaseLockings
                            PhaseLocking=struct('PLV',[],'times',EEGPL.times,'freqs',[4:20],'chanlocs',EEGPL.chanlocs,'channels',[]);
                            channels={EEGPL.chanlocs.labels};
                            PhaseLocking.channels=cell(2,length(Morlets)-1);
                            PhaseLocking.PLV=cell(length(Morlets)-1,1);%zeros(length(Morlets),length(Morlets),size(Morlets{1},1),size(Morlets{1},2)); %Electrode x Electrode x Freq x times
                            for el1=1:length(Morlets)-1
                                PhaseLocking.channels{1,el1}=channels{el1};
                                PhaseLocking.channels{2,el1}=channels(el1+1:length(Morlets));
                                PhaseLocking.PLV{el1}=zeros(length(Morlets)-el1,size(Morlets{1},1),size(Morlets{1},2)); %electrode x Freq x times
                                for el2=el1+1:length(Morlets)
                                    [PhaseLocking.PLV{el1}(el2-el1,:,:)]=fPLVangle(Morlets{el1},Morlets{el2});
                                    
                                end
                                
                            end
                            
                            
                            
                            save([newfilepath filename '_' eventnames{ide}{eco} '_PhaseLocking.mat'],'PhaseLocking');
                            clear PhaseLocking Morlets
                        end
                    catch
                        disp(['PhaseLocking processing failed: ' filename]);
                    end
                end
                
                %% Coherence Section
                if Run_Coherence==true
                    try
                        if ~exist([newfilepath filename '_' eventnames{ide}{eco} '_Coherence.mat'],'file')
                            
                            newdata=EEG.data(:,:,neweventlist); %Electrode x time x trials
                            

                            
                            % Now contruct Coherences
                            Coherence=struct('Coherence',[],'freqs',[],'chanlocs',EEG.chanlocs,'channels',[]);
                            Coherence.channels={EEG.chanlocs.labels};


params=struct('Fs',EEG.srate,'fpass',[4 20],'tapers',[3 5]);
        [C,~,~,~,~,f]=coherencyc(squeeze(newdata(1,:,:)),squeeze(newdata(2,:,:)),params);
Coherence.freqs=f;
        coher=zeros(size(newdata,1),size(newdata,1),size(C,1),size(C,2)); % Electrode x Electrode x frequency x trial

for el1=1:size(coher,1)
    firstdata=squeeze(newdata(el1,:,:));
    parfor el2=el1:size(coher,2)
                C=coherencyc(firstdata,squeeze(newdata(el2,:,:)),params);
                coher(el1,el2,:,:)=C;
                
    end
end
for el1=1:size(coher,1)
    for el2=el1:size(coher,2)
coher(el2,el1,:,:)=coher(el1,el2,:,:);
    end
end

Coherence.Coherence=coher;
                            
                            
                            
                            save([newfilepath filename '_' eventnames{ide}{eco} '_Coherence.mat'],'Coherence');
                            clear Coherence Morlets
                        end
                    catch
                        disp(['Coherence processing failed: ' filename]);
                    end
                end
            end
            
        end
    catch
        disp(['(all) ERP processing failed: ' filename]);
    end
end
