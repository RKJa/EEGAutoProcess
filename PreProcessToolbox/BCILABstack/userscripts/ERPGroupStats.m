% This should be run after ERPstatsfind

origfilepath='E:\AllsubjectsERPs\Total_AID_EEG\EEG-AID\Post-EEG-AID\MT'; %Folder where all the data is stored
replacefilepath='E:\GroupPlots\Total_AID_EEG\EEG-AID\Post-EEG-AID\MT';


filetype='ERPs.mat'; %Ending- all raw data should be labelled ending from 1 up to 9. The _processed is output from FilterEpochEEG

experiment_types={'_PV','_ND','_AD','_ID'}; % Each one will produce a different file

electrodelist={'Fp1','Fpz','Fp2'};

line_types={'Pre','Post'}; % Each one will produce a different plot line

stat_types={'P1amp','P1lat'};
numgrouplist=[101:270];
%%
ERPGroupSt=struct;

grouplist=cellstr(num2str(numgrouplist'))';

fullfileList = getAllFiles(origfilepath);
Fileidx=strfind(fullfileList,filetype); Fileidx=find(~cellfun(@isempty,Fileidx)); %Find t
fullfileList=fullfileList(Fileidx); %Extract just these files

for exp=1:length(experiment_types)
    expidx=strfind(fullfileList,experiment_types{exp}); expidx=find(~cellfun(@isempty,expidx));
    for lin=1:length(line_types)
        sheet_name=['Exp' experiment_types{exp} '_' line_types{lin}];
        ERPGroupSt.(sheet_name)=struct;
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

                for st=1:length(stat_types)
                for el=1:length(electrodelist)
                    column_name=[stat_types{st} '_' electrodelist{el}];
                [~,chanidx]=intersect(ERP.channels,electrodelist{el});
                ERPGroupSt.(sheet_name).(column_name){gr}=ERP.(stat_types{st})(chanidx);
                end
                end
            end
        end
    end
end

%% Write to Excelfile
sheets=fieldnames(ERPGroupSt);
for sh=1:length(sheets)
columns=fieldnames(ERPGroupSt.(sheets{sh}));
clear currentdata;
currentdata=['subject';num2cell(numgrouplist)'];
for col=1:length(columns)
    currentdata{1,col+1}=columns{col};
    inputdata=ERPGroupSt.(sheets{sh}).(columns{col});
    currentdata(2:length(inputdata)+1,col+1)=inputdata;
end
xlswrite('ERPStats.xls',currentdata,sheets{sh});
end