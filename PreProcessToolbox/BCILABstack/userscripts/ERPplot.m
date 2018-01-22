% Any issues Rajat_Jain@IEEE.org
origfilepath='F:\NoBCIpilot\ERPStats'; %Folder where all the data is stored
replacefilepath='F:\NoBCIpilot\ERPplots';
filetype='_ERPs.mat'; %Ending- all raw data should be labelled ending from 1 up to 9. The _processed is output from FilterEpochEEG

annotate_components=true; % Label N1, P1 etc

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

% Temporary
%load('electrodelist.mat');
%%
flatlist=electrodelist';
flatlist=flatlist(:);
for k=1:length(flatlist)
    if ~isempty(flatlist{k})
        flatlist{k}=lower(flatlist{k});
    end
end
%% Now let's Process!

fileList = getAllFiles(origfilepath);
Fileidx=strfind(fileList,filetype); Fileidx=find(~cellfun(@isempty,Fileidx)); %Find the cleaned set Files
fileList=fileList(Fileidx); %Extract just these files

for fn=1:length(fileList)
            pathsep=strfind(fileList{fn},filesep);pathsep=pathsep(end); %find where the directory ends and filename starts
        filename=fileList{fn}(pathsep+1:end-length(filetype));
        
        filepath=fileList{fn}(1:pathsep);
            newfilepath=strrep(filepath, origfilepath, replacefilepath);
            if ~exist(newfilepath,'dir');
                mkdir(newfilepath);
            end
            
%     pathsep=strfind(fileList{fn},filesep);pathsep=pathsep(end); %find where the directory ends and filename starts
%     filename=fileList{fn}(pathsep+1:end-length(filetype));
%     filepath=fileList{fn}(1:pathsep);
    if ~exist([filepath filename '_ERPs.png'],'file');
    load([filepath filename filetype]);
    
    %% Start Plotting
    %fig=figure; 
    figure('Position', [0,0, 5000, 5000]);
lim=max(abs(ERP.data(:))); %Use for axis limits
    for k=1:size(ERP.data,1)
        chanidx=find(strcmp(flatlist,lower(ERP.chanlocs(k).labels)));
        if isempty(chanidx)
            disp(['Cannot Find Channel ' ERP.chanlocs(k).labels ' (electrode no ' num2str(k) ')']);
        else
       subplot(size(electrodelist,1),size(electrodelist,2),chanidx);hold on;
       plot(ERP.times,ERP.data(k,:),'Color','k');
                   line([0 0],[-lim lim],'Color','k'); % zero line

            title(ERP.chanlocs(k).labels);
            if annotate_components
            % P1 
            scatter(ERP.P1lat(k),ERP.P1amp(k),'r');
            text(ERP.P1lat(k),ERP.P1amp(k),['P1 ' num2str(ERP.P1amp(k),'%.2f') 'at ' num2str(ERP.P1lat(k),'%.2f')],'Color','r');
        % N1 
            scatter(ERP.N1lat(k),ERP.N1amp(k),'b');
            text(ERP.N1lat(k),ERP.N1amp(k),['N1 ' num2str(ERP.N1amp(k),'%.2f') 'at ' num2str(ERP.N1lat(k),'%.2f')],'Color','b');
                % P300
            scatter(ERP.P300lat(k),ERP.P300amp(k),'g');
            text(ERP.P300lat(k),ERP.P300amp(k),['P300 ' num2str(ERP.P300amp(k),'%.2f') 'at ' num2str(ERP.P300lat(k),'%.2f')],'Color','g');
            end
            axis([ERP.times(1) ERP.times(end) -lim lim]);    
        end
        
    end
    
    %% Print
    saveas(gcf,[newfilepath filename '_ERPs'],'fig');
    set(gcf,'PaperUnits', 'inches','PaperPositionMode', 'manual');
    set(gcf,'PaperSize',[300 300]);
    %set(gcf,'PaperPositionMode = 'manual';
set(gcf,'PaperPosition', [0 0 40 25]);

saveas(gcf,[newfilepath filename '_ERPs.png']);
close(gcf);
    end
end