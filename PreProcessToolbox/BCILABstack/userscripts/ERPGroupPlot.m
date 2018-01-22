% This should be run after ERPstatsfind

origfilepath='F:\cBCI_ERPstats\'; %Folder where all the data is stored
replacefilepath='F:\cBCIGroupPlots\';


filetype='ERPs.mat'; %Ending- all raw data should be labelled ending from 1 up to 9. The _processed is output from FilterEpochEEG

experiment_types={'_'}; % Each one will produce a different file

electrodelist=cell(10,9);
electrodelist(1,4:6)={'lateralorbitofrontal L','Fpz','Fp2'};
electrodelist(2,3:7)={'AF7','AF3','Afz','AF4','AF8'};
electrodelist(3,:)={'F7','F5','F3','F1','Fz','F2','F4','F6','F8'};
electrodelist(4,:)={'FT7','FC5','FC3','FC1','FCz','FC2','FC4','FC6','FT8'};
electrodelist(5,:)={'T7','C5','C3','C1','Cz','C2','C4','C6','T8'};
electrodelist(6,:)={'TP7','CP5','CP3','CP1','CPz','CP2','CP4','CP6','TP8'};
electrodelist(7,:)={'P7','P5','P3','P1','Pz','P2','P4','P6','P8'};
electrodelist(8,2:8)={'P9','PO7','PO3','POz','PO4','PO8','P10'};
electrodelist(9,4:6)={'O1','Oz','O2'};
electrodelist(10,5)={'Iz'};


line_types={'_Targets','HighConflict','LowConflict'}; % Each one will produce a different plot line
line_colours={'r','b','g'};
%grouplist=[101,103,104,105,107,111,112,114,117,118,120,121,126,128,130,131,132,134,135,139,142,144,145]; % This is a list of the files that will be merged into one
grouplist=[002];
grouplist=cellstr(num2str(grouplist'))';

fullfileList = getAllFiles(origfilepath);
Fileidx=strfind(fullfileList,filetype); Fileidx=find(~cellfun(@isempty,Fileidx)); %Find t
fullfileList=fullfileList(Fileidx); %Extract just these files
for exp=1:length(experiment_types)
    subplot_list=cell([size(electrodelist),length(line_types)]); % This is a cell array of cell arrays- all values will be compiled in here
    expidx=strfind(fullfileList,experiment_types{exp}); expidx=find(~cellfun(@isempty,expidx));
    for lin=1:length(line_types)
        linidx=strfind(fullfileList,line_types{lin}); linidx=find(~cellfun(@isempty,linidx)); %Find the
        for gr=1:length(grouplist)
            subidx=strfind(fullfileList,grouplist{gr}); subidx=find(~cellfun(@isempty,subidx));
            fileidx=intersect(intersect(expidx,linidx),subidx);
            if isempty(fileidx)
                disp(['Did not find ' experiment_types{exp} ' ' line_types{lin} ' ' grouplist{gr}]);
            elseif length(fileidx)>1
                for fdl=1:length(fileidx)
                    disp(['Too many files : ' fullfileList{fileidx(fdl)}]);
                end
            else
                load(fullfileList{fileidx});
                for xc=1:size(electrodelist,1)
                    for yc=1:size(electrodelist,2)
                        if ~isempty(electrodelist{xc,yc})
                        chanidx=find(strcmp(ERP.channels,electrodelist{xc,yc})); %chanidx=find(~cellfun(@isempty,chanidx));

                        if ~isempty(chanidx)
                            if isempty(subplot_list{xc,yc,lin})
                            subplot_list{xc,yc,lin}=ERP.data(chanidx,:);
                            else
                                subplot_list{xc,yc,lin}=[subplot_list{xc,yc,lin};ERP.data(chanidx,:)];
                                
                            end
                        end
                        end
                    end
                end
                
             
            end
        end
    end
    
    %% Plot the data for this experiment type
    figure;hold on;
    for xc=1:size(electrodelist,1)
                    for yc=1:size(electrodelist,2)
                       
                      for lin=1:length(line_types)
                        if ~isempty(subplot_list{xc,yc,lin})
                       subplot(size(electrodelist,1),size(electrodelist,2),yc+(xc-1)*size(electrodelist,2)); hold on;
                       plot(ERP.times,mean(subplot_list{xc,yc,lin},1),line_colours{lin});
                        title(electrodelist{xc,yc});
                        end
                      end
                    end
    end
     %saveas(gcf,[replacefilepath experiment_types{exp} ' ' line_types{lin}  '_ERPGroup'],'fig');
     saveas(gcf,'F:\cBCIGroupPlots\test','fig');
     close gcf;
end
