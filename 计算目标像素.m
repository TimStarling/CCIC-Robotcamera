
clc;
clear;
% 读取十六进制文件内容，按空格分割为单元格数组
hexData = textread('color.txt', '%s', 'delimiter', ' ');

outputStr = '';
len = length(hexData);
i = 1;

while i <= len
    currentByte = hex2dec(hexData{i});
    
    if currentByte == 0x3a % 处理冒号（:）
        outputStr = [outputStr, char(currentByte)]; % 添加冒号字符
        
        % 检查后续是否有足够的两字节数据
        if i + 2 > len
            error('文件格式错误：冒号后数据不足');
        end
        
        % 提取两字节数据并转换为十进制
        highByte = hex2dec(hexData{i+1});
        lowByte = hex2dec(hexData{i+2});
        decValue = highByte * 256 + lowByte;
        outputStr = [outputStr, num2str(decValue)];
        
        i = i + 3; % 跳过冒号、两字节数据和后续逗号（由下一次循环处理逗号）
    elseif currentByte == 0x2c || currentByte == 0x0d || currentByte == 0x0a % 处理逗号或换行符
        outputStr = [outputStr, char(currentByte)];
        i = i + 1;
    else % 其他十六进制转换为ASCII字符
        outputStr = [outputStr, char(currentByte)];
        i = i + 1;
    end
end

% 写入结果到output.txt
fid = fopen('output1.txt', 'w');
if fid == -1
    error('无法创建输出文件');
end
fwrite(fid, outputStr, 'char');
fclose(fid);

disp('转换完成，结果已保存到output.txt');