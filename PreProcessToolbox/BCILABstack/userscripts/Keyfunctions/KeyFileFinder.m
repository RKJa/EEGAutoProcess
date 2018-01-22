% This function will produce a list of files (both full list including
% path, and just filenames) of files whose names contain everything from a
% list of keywords and a single file for each in a list of subjectlist. The
% outputs will be the same length as subjectlist in the appropriate order

% All inputs/outputs are cell arrays of strings other than inputpath which
% is just a string

% Issues- Rajat_Jain@IEEE.org

%%
function [ fileList,filenames ] = KeyFileFinder(inputpath,keywords,subjectlist )

%% Get list of all files
 fileList = getAllFiles(inputpath);
 %% Seperate into list of filenames
 seploc=strfind(fileList,filesep); % Find where the path seperators are (so we can find the actual filename)
 filenames=cell(length(fileList),1);
 for fn=1:length(filenames)
     filenames{fn}=fileList{fn}(seploc{fn}(end)+1:end); %Store just the file (Not folder) names.
 end
 
 %% Get list of filenames containing keywords
 validfiles=ones(length(filenames),1); %find all files containing the key words (assume correct then remove incorrect)
 for fk=1:length(keywords)
     tmpidx=strfind(lower(filenames),lower(keywords{fk}));
     tmpidx=find(cellfun(@isempty,tmpidx)); % FInd where the key word does not exist
     validfiles(tmpidx)=0;
 end
 fileList=fileList(logical(validfiles));
 filenames=filenames(logical(validfiles));
 
 %% Get list of each unique file
subjectidx=zeros(length(subjectlist),1);
for sl=1:length(subjectlist)
    tmpv=strfind(filenames,subjectlist{sl}); % Find where the file for this subject is located
    fidx=find(~cellfun(@isempty,tmpv));
    if isempty(fidx)
        disp(['No file found for subject ' subjectlist{sl}]);
    else
        if length(fidx)>1
        disp([num2str(length(fidx)) 'files found for subject ' subjectlist{sl} ' Taking the first one found']);
        end
        subjectidx(sl)=fidx(1);
    end
end
 fileList=fileList(subjectidx);
 filenames=filenames(subjectidx);

end

