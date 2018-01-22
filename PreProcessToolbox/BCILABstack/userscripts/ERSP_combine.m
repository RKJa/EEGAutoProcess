
 frequencylimits=[4,8];
 timelimits=[-300,300];
 channels={'F3','Fp1','AF7','O2'};
 filekeywords={'Filter','Pre','ERSP'};
subjects=[101,103,135,152]; 
origfilepath='E:\AllsubjectsERPs\';
 
 
 %% Setup 
 subjectlist=cellstr(num2str(subjects','%03i'))'; % Convert subject list to string
 [fileList, filenames]=KeyFileFinder(origfilepath,filekeywords,subjectlist);

 DataOut=cell(length(fileList),1);
 tic
 
 %% Process
 for fn=1:length(fileList)
     
     % Load the correct file
     load(fileList{fn});
     
     % Find the correct frequency band
     freqidx=find(ERSP.freqs>=frequencylimits(1) & ERSP.freqs<=frequencylimits(2));
     
     % Find where the time limits are
     timeidx=find(ERSP.times>=timelimits(1) & ERSP.times<=timelimits(2));

     % Find where the channels are located (IN ORDER)
     chanidx=[];
     for ch=1:length(channels)
     [~,chanidx(ch)]=intersect(ERSP.channels,channels{ch});
     end
     
     % AND extract (and compress by frequency band)
     DataOut{fn}=ERSP.data(chanidx,freqidx,timeidx);
     
     
 end
 toc
 StatOut=zeros(length(fileList),1);
 for k=1:length(DataOut)
     
     StatOut(k)=mean(DataOut{k}(:));
 end
     
    
     
    