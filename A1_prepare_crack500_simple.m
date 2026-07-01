clear; clc;

% Change this path to your downloaded CRACK500 folder.
sourceRoot = '/Users/0431196856zym./Documents/MATLAB/capstone project/pavement crack datasets/CRACK500';

projectRoot = fileparts(mfilename('fullpath'));
if isempty(projectRoot)
    projectRoot = pwd;
end
imageOutDir = fullfile(projectRoot, 'data', 'images');
maskOutDir = fullfile(projectRoot, 'data', 'masks');

ensureDir(imageOutDir);
ensureDir(maskOutDir);

splits = {'traincrop', 'valcrop', 'testcrop'};
totalPairs = 0;

for s = 1:numel(splits)
    splitDir = fullfile(sourceRoot, splits{s});
    if ~isfolder(splitDir)
        warning('Folder not found, skipped: %s', splitDir);
        continue;
    end

    copied = copyJpgPngPairs(splitDir, imageOutDir, maskOutDir, splits{s});
    totalPairs = totalPairs + copied;
end

fprintf('\nFinished. Copied %d CRACK500 image-mask pairs.\n', totalPairs);
fprintf('Images: %s\n', imageOutDir);
fprintf('Masks:  %s\n', maskOutDir);

function copied = copyJpgPngPairs(splitDir, imageOutDir, maskOutDir, prefix)
jpgFiles = [dir(fullfile(splitDir, '*.jpg')); dir(fullfile(splitDir, '*.JPG')); ...
    dir(fullfile(splitDir, '*.jpeg')); dir(fullfile(splitDir, '*.JPEG'))];

copied = 0;

for i = 1:numel(jpgFiles)
    imagePath = fullfile(jpgFiles(i).folder, jpgFiles(i).name);
    [~, baseName, imageExt] = fileparts(imagePath);

    maskPath = fullfile(jpgFiles(i).folder, [baseName '.png']);
    if ~isfile(maskPath)
        maskPath = fullfile(jpgFiles(i).folder, [baseName '.PNG']);
    end

    if ~isfile(maskPath)
        warning('Mask not found for %s', imagePath);
        continue;
    end

    outBase = [prefix '_' baseName];
    copyfile(imagePath, fullfile(imageOutDir, [outBase imageExt]));
    copyfile(maskPath, fullfile(maskOutDir, [outBase '.png']));
    copied = copied + 1;
end

fprintf('%s: copied %d pairs.\n', prefix, copied);
end

function ensureDir(pathToDir)
if ~isfolder(pathToDir)
    mkdir(pathToDir);
end
end
