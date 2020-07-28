close all;clear;clc

Fs = 9000;      % Sample rate (Hz)
total_len = Fs*15;      % signal time length
f_seq = 1125;
F = f_seq * (0: Fs/(2*f_seq)-1);        % start of each frequency band
bytesPerSample = 2;
S = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
path = dir('background\*.pcm');     % read background dirs
filelist = {path.name};

for count = 1:2e3
    % random read a background
    while(1)        
        k = randi([1 length(filelist)]);
        background_name = filelist{k};      
        audiopath = cell2mat(fullfile('background',filelist(k)));
        background_name = strsplit(background_name, '.');
        background_name = background_name{1};
        if ~isempty(strfind(background_name, 'zhongdi'))
            fid_2 = fopen(audiopath, 'rb');
            y = fread(fid_2, 'int16')';
            fclose(fid_2);
            len = length(y);
            if len >  total_len
                break;
            end
        end
    end
    SNR_dB = randi([-10, 10]);
    code_speed = 2 * randi([5, 10]);    % 10~20wpm
    sindex = randi([1, len-total_len]);
    y = y(sindex: sindex+total_len-1);
    power_y = sum(y.^2)/length(y);
    
    % write annotations to json file
    fid = fopen(['data/',num2str(count),'_', num2str(SNR_dB),'db_', num2str(code_speed),'wpm.DR.txt'],'w');

    for f_start = F      
        i = randi([1 2]);
        % generate no signal
        if i == 1
            continue; 
        end

        % generate Morse
        if i ==2
            range_scale = sqrt(sqrt(2)*power_y*(10^(SNR_dB/10)));
            time_dit = 1.2 / code_speed;
            Fc = f_start + randi([200, f_seq-200]);  
            k = randi([1 26],1,randi([2 10]));   % random generate 2~10 character
            jitter = randi([0 2])*100;     % 0~200Hz frequency jitter     
            text = S(k);
            morsecode = morse(Fs,time_dit,Fc,text, jitter);
            morsecode = real(morsecode);            
            morsecode_scale = range_scale * morsecode;       

            if total_len-length(morsecode_scale)+1 < 1
                continue;
            end
            index = randi([1,total_len-length(morsecode_scale)+1]);
            y(index:index+length(morsecode_scale)-1) = y(index:index+length(morsecode_scale)-1) + morsecode_scale;

            FreqU = min(Fc + 200, Fs/2-1);      % fix BBox height to 400Hz
            FreqD = max(Fc - 200, 0);
            Start = max((index-1) / Fs - 0.5, 0);   % add 0.5s before and after the time
            End = min((index+length(morsecode_scale)-1) / Fs + 0.5, 20);
            % writte annotation
            bbox = struct('FreqD',FreqD,'FreqU',FreqU,'DateTimeStart',round(Start*1e7),...
            'DateTimeEnd',round(End*1e7),'Content',text);
            bbox_json = jsonencode(bbox);
            fprintf(fid,['\r\n',bbox_json],'utf-8');
        end 
    end
    fclose(fid);
    
    % save wav
    y = y / max(abs(y));  % normalize
    audiowrite(['data/',num2str(count),'_', num2str(SNR_dB),'db_', num2str(code_speed),'wpm.wav'], y, Fs);

end