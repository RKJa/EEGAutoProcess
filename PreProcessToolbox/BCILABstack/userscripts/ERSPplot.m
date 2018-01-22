% Any issues Rajat_Jain@IEEE.org
filepath='E:\AllsubjectsERPs\'; %Folder where all the data is stored
filetype='_ERSP.mat'; %Ending- all raw data should be labelled ending from 1 up to 9. The _processed is output from FilterEpochEEG

types={'data','itc','itcphase'};

electrodelist=cell(10,9);
electrodelist(1,4:6)={'Fp1','Fpz','Fp2'};
electrodelist(2,3:7)={'AF7','AF3','Afz','AF4','AF8'};
electrodelist(3,:)={'F7','F5','F3','F1','Fz','F2','F4','F6','F8'};
electrodelist(4,:)={'FT7','FC5','FC3','FC1','FCz','FC2','FC4','FC6','FT8'};
electrodelist(5,:)={'T7','C5','C3','C1','Cz','C2','C4','C6','T8'};
electrodelist(6,:)={'TP7','CP5','CP3','CP1','CPz','CP2','CP4','CP6','TP8'};
electrodelist(7,:)={'P7','P5','P3','P1','Pz','P2','P4','P6','P8'};
electrodelist(8,2:8)={'P9','PO7','PO3','POz','PO4','PO8','P10'};
electrodelist(9,4:6)={'O1','Oz','O2'};
electrodelist(10,5)={'Iz'};
flatlist=electrodelist';
flatlist=flatlist(:);
for k=1:length(flatlist)
    if ~isempty(flatlist{k})
        flatlist{k}=lower(flatlist{k});
    end
end
%flatlist(isempty(flatlist))='';
%% Now let's Process!

fileList = getAllFiles(filepath);
Fileidx=strfind(fileList,filetype); Fileidx=find(~cellfun(@isempty,Fileidx)); %Find the cleaned set Files
fileList=fileList(Fileidx); %Extract just these files

for fn=1:length(fileList)
    pathsep=strfind(fileList{fn},filesep);pathsep=pathsep(end); %find where the directory ends and filename starts
    filename=fileList{fn}(pathsep+1:end-length(filetype));
    filepath=fileList{fn}(1:pathsep);
    load([filepath filename filetype]);
    
    for tc=1:length(types)
        %% Start Plotting
        %fig=figure;
        figure('Position', [0,0, 5000, 5000]);
        %lim=max(abs(ERSP.data(:))); %Use for axis limits
        for k=1:size(ERP.data,1)
            chanidx=find(strcmp(flatlist,lower(ERP.chanlocs(k).labels)));
            if isempty(chanidx)
                disp(['Cannot Find Channel ' ERP.chanlocs(k).labels ' (electrode no ' num2str(k) ')']);
            else
                subplot(size(electrodelist,1),size(electrodelist,2),chanidx);hold on;
                image(ERP.times,ERSP.freqs,squeeze(ERSP.(types{tc})(k,:,:)),'CDataMapping','scaled');
                
                title(ERP.chanlocs(k).labels);
                
                
                axis([ERSP.times(1) ERSP.times(end) ERSP.freqs(1)-0.5 ERSP.freqs(end)+0.5]);
            end
            
        end
        
        %% Print
    saveas(gcf,[filepath filename '_ERSP_' types{tc}],'fig');
        set(gcf,'PaperUnits', 'inches','PaperPositionMode', 'manual');
        set(gcf,'PaperSize',[300 300]);
        %set(gcf,'PaperPositionMode = 'manual';
        set(gcf,'PaperPosition', [0 0 40 25]);
        
        saveas(gcf,[filepath filename '_ERSP_' types{tc} '.png']);
        close(gcf);
    end
end