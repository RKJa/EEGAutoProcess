% This should be run after PreProcessEEG and FilterEpochEEG. It takes all
% files ending in 1 and looks for those then ending in 2, 3 etc and merges
% them. Titles must be identical other than the final value being 1-9. it
% DOES NOT necessarily work with values above 9. If you want this feature,
% it can be built.

% Any issues Rajat_Jain@IEEE.org

%% Load in BCILAB
run(['..\bcilab']);%Start BCIlab
    pop_editoptions( 'option_single', false);
    
    %%
origfilepath='F:\PrePostTest\Epoched'; %Folder where all the data is stored
replacefilepath='F:\cBCImerged\';
%filetype='1_processed.set'; %Ending- all raw data should be labelled ending from 1 up to 9. The _processed is output from FilterEpochEEG
numvals=cellstr(num2str([1:10]','%02i')); % Cell array of merge identifiers
filetype={'_',numvals,'_processed.set'};




%% Now let's Merge!
allfiletype=filetype{end};
fileList = getAllFiles(origfilepath);
first_filetype=[filetype{1} filetype{2}{1} filetype{3}];
Fileidx=strfind(fileList,first_filetype); Fileidx=find(~cellfun(@isempty,Fileidx)); %Find the cleaned set Files
fileList=fileList(Fileidx); %Extract just these files
filesused={};
for fn=1:length(fileList)
    try
        pathsep=strfind(fileList{fn},filesep);pathsep=pathsep(end); %find where the directory ends and filename starts
        filename=fileList{fn}(pathsep+1:end-length(first_filetype));
        filepath=fileList{fn}(1:pathsep);
        newfilepath=strrep(filepath, origfilepath, replacefilepath);
        if ~exist([newfilepath filename '_merged.set'],'file') %Make sure we haven't already processed this
            if ~exist(newfilepath,'dir'); % Make sure the directory exists to save the file into
                mkdir(newfilepath);
            end
            
            EEG=pop_loadset([filename first_filetype],filepath);
            
            filesused{end+1}=[filepath filename first_filetype];
            fcount=2;
            while fcount~=0 && fcount<=length(filetype{2})
                newfile= [filename filetype{1} filetype{2}{fcount} filetype{3}];  %deleted [filename num2str(fcount)... ] to try to merge all files of same filetype
                if exist([filepath newfile],'file')
                    
                    newEEG=pop_loadset(newfile,filepath);
                    
                    filesused{end+1}=[filepath,newfile];
                    EEG=pop_mergeset(EEG,newEEG);
                    fcount=fcount+1;
                else
                    fcount=0;
                end
                
            end
            pop_saveset(EEG,'filename',[filename '_merged'],'filepath',newfilepath);  %filetype was filename, but changed to try to merge all files of same filetype
            fileID = fopen([newfilepath filename '_merged Files Included.txt'],'w');
            fprintf(fileID,'%s\r\n', filesused{:});
            fclose(fileID);
        else
            filesused{end+1}=[filepath filename filetype{1} filetype{2}{1} filetype{3}];
            fcount=2;
            while fcount~=0
                newfile= [filename filetype{1} filetype{2}{fcount} filetype{3}];
                if exist([filepath newfile],'file')
                    filesused{end+1}=[filepath,newfile];
                    fcount=fcount+1;
                else
                    fcount=0;
                end
                
            end
        end
    catch Error
        disp(['Could not merge ' fileList{fn}]);
        fileID = fopen([replacefilepath 'MergeEEGfailures' date '.txt'],'a');
            fprintf(fileID,'\n%s\n',[fileList{fn}]);
fprintf(fileID,'\t%s\n',[Error.message]);
fprintf(fileID,'\t%s\n',['Line ' num2str(Error.stack(end).line) ' ' Error.stack(end).file]);
fclose(fileID);
    end
end

%% Now copy unmerged files
fileList = getAllFiles(origfilepath);
Fileidx=strfind(fileList,allfiletype); Fileidx=find(~cellfun(@isempty,Fileidx)); %Find the cleaned set Files
fileList=fileList(Fileidx); %Extract just these files
[~,idx]=intersect(fileList,filesused); % Find which files were copied
fileList(idx)=[]; %Remove these values so we just have the uncopied values

for fn=1:length(fileList)
    newfile=strrep(fileList{fn},origfilepath,replacefilepath);
    
    pathsep=strfind(fileList{fn},filesep);pathsep=pathsep(end); %find where the directory ends and filename starts
    filepath=fileList{fn}(1:pathsep);
    newfilepath=strrep(filepath, origfilepath, replacefilepath);
    if ~exist(newfilepath,'dir'); % Make sure the directory exists to save the file into
        mkdir(newfilepath);
    end
    
    copyfile(fileList{fn},newfile);
    if exist([fileList{fn}(1:end-3) 'fdt'],'file')
        copyfile([fileList{fn}(1:end-3) 'fdt'],[newfile(1:end-3) 'fdt']);
    end
end

fileID = fopen([replacefilepath 'MergeFiles_unchanged' date '.txt'],'w');
fprintf(fileID,'%s\r\n', fileList{:});
fclose(fileID);