clear; clc; close all;

projectRoot = fileparts(mfilename('fullpath'));
if isempty(projectRoot)
    projectRoot = pwd;
end

cfg = struct();
cfg.imageDir = fullfile(projectRoot, 'data', 'images');
cfg.maskDir = fullfile(projectRoot, 'data', 'masks');
cfg.resultDir = fullfile(projectRoot, 'results');

cfg.maxImages = 20;
cfg.targetSize = [480 640];
cfg.multiScaleSizes = [240 320; 480 640; 720 960];
cfg.multiScaleImageCount = 5;

% If no real calibration is available, keep this as 1 and report length in
% normalized pixel units. Replace it with measured mm/px when calibrated.
cfg.originalMmPerPixel = 1.0;

cfg.gaussianSigma = 1.0;
cfg.claheClipLimit = 0.02;
cfg.claheNumTiles = [8 8];

cfg.sauvolaWindowSize = [31 31];
cfg.sauvolaK = 0.34;
cfg.sauvolaR = 0.5;

cfg.openRadius = 1;
cfg.closeRadius = 1;
cfg.minObjectArea = 50;
cfg.spurPruneIterations = 20;
cfg.junctionDisplayRadius = 3;

ensureDir(cfg.resultDir);

imageFiles = listInputImages(cfg.imageDir);
if isempty(imageFiles)
    error('No CRACK500 jpg images found in %s', cfg.imageDir);
end

if isfinite(cfg.maxImages)
    imageFiles = imageFiles(1:min(cfg.maxImages, numel(imageFiles)));
end

methodRows = table();
componentRows = table();
multiScaleRows = table();

fprintf('A1 Classical Pipeline started. Processing %d image(s).\n', numel(imageFiles));

for i = 1:numel(imageFiles)
    imagePath = imageFiles{i};
    [~, baseName, ~] = fileparts(imagePath);
    fprintf('[%d/%d] %s\n', i, numel(imageFiles), baseName);

    img = imread(imagePath);
    maskPath = findMaskFile(cfg.maskDir, baseName);
    hasGroundTruth = ~isempty(maskPath);

    if hasGroundTruth
        gtMaskOriginal = maskToLogical(imread(maskPath));
    else
        gtMaskOriginal = [];
        warning('Ground truth mask not found for %s. Metrics will be NaN.', baseName);
    end

    [out, debug] = runClassicalPipeline(img, cfg);

    gtMask = [];
    if hasGroundTruth
        gtMask = imresize(gtMaskOriginal, cfg.targetSize, 'nearest');
        gtMask = maskToLogical(gtMask);
    end

    methodRows = appendTable(methodRows, makeMethodRow(baseName, 'Otsu', out.otsuMask, gtMask, hasGroundTruth, out.otsuRuntimeSec));
    methodRows = appendTable(methodRows, makeMethodRow(baseName, 'Sauvola', out.sauvolaMask, gtMask, hasGroundTruth, out.sauvolaRuntimeSec));
    methodRows = appendTable(methodRows, makeMethodRow(baseName, 'Canny_display', out.cannyMask, gtMask, hasGroundTruth, out.cannyRuntimeSec));

    componentRows = appendTable(componentRows, measureCrackComponents(baseName, out.prunedSkeleton, out.sauvolaMask, out.effectiveMmPerPixel));

    saveResultImages(baseName, out, debug, cfg);

    if i <= cfg.multiScaleImageCount && hasGroundTruth
        multiScaleRows = appendTable(multiScaleRows, runMultiScaleAnalysis(baseName, img, gtMaskOriginal, cfg));
    end
end

writetable(methodRows, fullfile(cfg.resultDir, 'method_metrics.csv'));
writetable(makeSummaryTable(methodRows), fullfile(cfg.resultDir, 'summary_metrics.csv'));
writetable(componentRows, fullfile(cfg.resultDir, 'crack_component_features.csv'));

if ~isempty(componentRows)
    sortedComponents = sortrows(componentRows, 'Length_mm', 'descend');
    topCount = min(5, height(sortedComponents));
    writetable(sortedComponents(1:topCount, :), fullfile(cfg.resultDir, 'top5_crack_features.csv'));
end

if ~isempty(multiScaleRows)
    writetable(multiScaleRows, fullfile(cfg.resultDir, 'multiscale_metrics.csv'));
end

fprintf('\nDone. Results saved to:\n%s\n', cfg.resultDir);

function [out, debug] = runClassicalPipeline(img, cfg)
rgb = toRGB(img);
gray = im2double(rgb2gray(rgb));

scaleY = cfg.targetSize(1) / size(gray, 1);
effectiveMmPerPixel = cfg.originalMmPerPixel / scaleY;

tPre = tic;
resizedRGB = imresize(rgb, cfg.targetSize, 'bilinear');
resizedGray = imresize(gray, cfg.targetSize, 'bilinear');
blurred = imgaussfilt(resizedGray, cfg.gaussianSigma);
enhanced = adapthisteq(blurred, ...
    'ClipLimit', cfg.claheClipLimit, ...
    'NumTiles', cfg.claheNumTiles, ...
    'Distribution', 'rayleigh');
preRuntimeSec = toc(tPre);

tOtsu = tic;
otsuThreshold = graythresh(enhanced);
otsuMaskRaw = enhanced < otsuThreshold;
otsuMask = postProcessMask(otsuMaskRaw, cfg);
otsuRuntimeSec = preRuntimeSec + toc(tOtsu);

tSauvola = tic;
sauvolaT = sauvolaThreshold(enhanced, cfg.sauvolaWindowSize, cfg.sauvolaK, cfg.sauvolaR);
sauvolaMaskRaw = enhanced < sauvolaT;
sauvolaMask = postProcessMask(sauvolaMaskRaw, cfg);
rawSkeleton = bwmorph(sauvolaMask, 'thin', Inf);
prunedSkeleton = bwmorph(rawSkeleton, 'spur', cfg.spurPruneIterations);
prunedSkeleton = bwareaopen(prunedSkeleton, cfg.spurPruneIterations);
junctions = detectJunctions(prunedSkeleton);
sauvolaRuntimeSec = preRuntimeSec + toc(tSauvola);

tCanny = tic;
cannyEdges = edge(enhanced, 'Canny');
cannyMask = imdilate(cannyEdges, strel('disk', 1));
cannyRuntimeSec = preRuntimeSec + toc(tCanny);

out = struct();
out.otsuMask = otsuMask;
out.sauvolaMask = sauvolaMask;
out.cannyMask = cannyMask;
out.rawSkeleton = rawSkeleton;
out.prunedSkeleton = prunedSkeleton;
out.junctions = junctions;
out.otsuRuntimeSec = otsuRuntimeSec;
out.sauvolaRuntimeSec = sauvolaRuntimeSec;
out.cannyRuntimeSec = cannyRuntimeSec;
out.effectiveMmPerPixel = effectiveMmPerPixel;

debug = struct();
debug.resizedRGB = resizedRGB;
debug.resizedGray = resizedGray;
debug.blurred = blurred;
debug.enhanced = enhanced;
debug.otsuThreshold = otsuThreshold;
debug.sauvolaThreshold = sauvolaT;
end

function mask = postProcessMask(mask, cfg)
mask = logical(mask);
mask = imopen(mask, strel('disk', cfg.openRadius));
mask = bwareaopen(mask, cfg.minObjectArea);
mask = imclose(mask, strel('disk', cfg.closeRadius));
mask = imfill(mask, 'holes');
mask = bwareaopen(mask, cfg.minObjectArea);
end

function threshold = sauvolaThreshold(gray, windowSize, k, R)
gray = im2double(gray);
if isscalar(windowSize)
    windowSize = [windowSize windowSize];
end

meanKernel = fspecial('average', windowSize);
localMean = imfilter(gray, meanKernel, 'replicate');
localMeanSq = imfilter(gray .^ 2, meanKernel, 'replicate');
localStd = sqrt(max(localMeanSq - localMean .^ 2, 0));

threshold = localMean .* (1 + k .* (localStd ./ R - 1));
threshold = min(max(threshold, 0), 1);
end

function junctions = detectJunctions(skeleton)
skeleton = logical(skeleton);
neighborCount = conv2(double(skeleton), ones(3), 'same') - double(skeleton);
junctions = skeleton & neighborCount >= 3;
end

function row = makeMethodRow(imageName, methodName, predMask, gtMask, hasGroundTruth, runtimeSec)
if hasGroundTruth
    m = evaluateBinaryMask(predMask, gtMask);
else
    m = emptyMetrics();
end

row = table({imageName}, {methodName}, hasGroundTruth, ...
    m.Precision, m.Recall, m.F1Score, m.IoU, m.Accuracy, ...
    m.TP, m.FP, m.FN, m.TN, runtimeSec, 1 / max(runtimeSec, eps), ...
    'VariableNames', {'ImageName', 'Method', 'GroundTruthAvailable', ...
    'Precision', 'Recall', 'F1Score', 'IoU', 'Accuracy', ...
    'TP', 'FP', 'FN', 'TN', 'RuntimeSec', 'FPS'});
end

function metrics = evaluateBinaryMask(predMask, gtMask)
predMask = maskToLogical(predMask);
gtMask = maskToLogical(gtMask);

if ~isequal(size(predMask), size(gtMask))
    predMask = imresize(predMask, size(gtMask), 'nearest');
    predMask = maskToLogical(predMask);
end

TP = sum(predMask(:) & gtMask(:));
FP = sum(predMask(:) & ~gtMask(:));
FN = sum(~predMask(:) & gtMask(:));
TN = sum(~predMask(:) & ~gtMask(:));

precision = TP / (TP + FP + eps);
recall = TP / (TP + FN + eps);
f1 = 2 * precision * recall / (precision + recall + eps);
iou = TP / (TP + FP + FN + eps);
accuracy = (TP + TN) / (TP + FP + FN + TN + eps);

metrics = struct('TP', TP, 'FP', FP, 'FN', FN, 'TN', TN, ...
    'Precision', precision, 'Recall', recall, 'F1Score', f1, ...
    'IoU', iou, 'Accuracy', accuracy);
end

function metrics = emptyMetrics()
metrics = struct('TP', NaN, 'FP', NaN, 'FN', NaN, 'TN', NaN, ...
    'Precision', NaN, 'Recall', NaN, 'F1Score', NaN, ...
    'IoU', NaN, 'Accuracy', NaN);
end

function rows = measureCrackComponents(imageName, skeleton, mask, mmPerPixel)
cc = bwconncomp(skeleton);
stats = regionprops(cc, 'Area', 'Orientation', 'Centroid');
distMap = bwdist(~mask);

rows = table();

for c = 1:cc.NumObjects
    pix = cc.PixelIdxList{c};
    lengthPx = numel(pix);
    widthPx = 2 * distMap(pix);

    if isempty(widthPx)
        meanWidthMm = 0;
        maxWidthMm = 0;
    else
        meanWidthMm = mean(widthPx) * mmPerPixel;
        maxWidthMm = max(widthPx) * mmPerPixel;
    end

    centroid = stats(c).Centroid;

    row = table({imageName}, c, lengthPx * mmPerPixel, meanWidthMm, maxWidthMm, ...
        stats(c).Orientation, centroid(1), centroid(2), ...
        'VariableNames', {'ImageName', 'CrackID', 'Length_mm', ...
        'MeanWidth_mm', 'MaxWidth_mm', 'Orientation_deg', ...
        'CentroidX_px', 'CentroidY_px'});

    rows = appendTable(rows, row);
end
end

function rows = runMultiScaleAnalysis(imageName, img, gtMaskOriginal, cfg)
rows = table();

for s = 1:size(cfg.multiScaleSizes, 1)
    cfgScale = cfg;
    cfgScale.targetSize = cfg.multiScaleSizes(s, :);

    [out, ~] = runClassicalPipeline(img, cfgScale);
    gtMask = imresize(gtMaskOriginal, cfgScale.targetSize, 'nearest');
    m = evaluateBinaryMask(out.sauvolaMask, gtMask);

    row = table({imageName}, cfgScale.targetSize(1), cfgScale.targetSize(2), ...
        m.Precision, m.Recall, m.F1Score, m.IoU, ...
        out.sauvolaRuntimeSec, 1 / max(out.sauvolaRuntimeSec, eps), ...
        'VariableNames', {'ImageName', 'Height', 'Width', ...
        'Precision', 'Recall', 'F1Score', 'IoU', 'RuntimeSec', 'FPS'});

    rows = appendTable(rows, row);
end
end

function saveResultImages(baseName, out, debug, cfg)
imwrite(debug.resizedGray, fullfile(cfg.resultDir, [baseName '_01_gray.png']));
imwrite(debug.enhanced, fullfile(cfg.resultDir, [baseName '_02_clahe.png']));
imwrite(out.otsuMask, fullfile(cfg.resultDir, [baseName '_03_otsu_mask.png']));
imwrite(out.sauvolaMask, fullfile(cfg.resultDir, [baseName '_04_sauvola_mask.png']));
imwrite(out.cannyMask, fullfile(cfg.resultDir, [baseName '_05_canny.png']));
imwrite(out.rawSkeleton, fullfile(cfg.resultDir, [baseName '_06_skeleton_raw.png']));
imwrite(out.prunedSkeleton, fullfile(cfg.resultDir, [baseName '_07_skeleton_pruned.png']));

overlay = overlayMask(debug.resizedRGB, out.sauvolaMask, [1 0 0], 0.45);
imwrite(overlay, fullfile(cfg.resultDir, [baseName '_08_overlay.png']));

junctionOverlay = overlayMask(debug.resizedRGB, out.rawSkeleton, [0 1 0], 0.65);
junctionDots = imdilate(out.junctions, strel('disk', cfg.junctionDisplayRadius));
junctionOverlay = paintMask(junctionOverlay, junctionDots, [1 0 0]);
imwrite(junctionOverlay, fullfile(cfg.resultDir, [baseName '_09_junctions.png']));

fourPanelPath = fullfile(cfg.resultDir, [baseName '_four_panel.png']);
saveFourPanelFigure(fourPanelPath, debug.resizedRGB, debug.enhanced, ...
    out.sauvolaMask, junctionOverlay, out.prunedSkeleton);
end

function saveFourPanelFigure(outPath, resizedRGB, enhanced, sauvolaMask, junctionOverlay, prunedSkeleton)
fig = figure('Visible', 'off', 'Position', [100 100 1200 850]);

subplot(2, 2, 1);
imshow(resizedRGB);
title('A. Resized input');

subplot(2, 2, 2);
imshow(enhanced);
title('B. Gaussian + CLAHE');

subplot(2, 2, 3);
imshow(sauvolaMask);
title('C. Sauvola mask');

subplot(2, 2, 4);
combined = overlayMask(junctionOverlay, prunedSkeleton, [1 1 0], 0.8);
imshow(combined);
title('D. Junctions + pruned skeleton');

print(fig, outPath, '-dpng', '-r150');
close(fig);
end

function summary = makeSummaryTable(methodRows)
methods = unique(methodRows.Method);
summary = table();

for i = 1:numel(methods)
    methodName = methods{i};
    idx = strcmp(methodRows.Method, methodName) & methodRows.GroundTruthAvailable;
    if ~any(idx)
        continue;
    end

    row = table({methodName}, sum(idx), ...
        nanMean(methodRows.Precision(idx)), ...
        nanMean(methodRows.Recall(idx)), ...
        nanMean(methodRows.F1Score(idx)), ...
        nanMean(methodRows.IoU(idx)), ...
        nanMean(methodRows.Accuracy(idx)), ...
        nanMean(methodRows.RuntimeSec(idx)), ...
        nanMean(methodRows.FPS(idx)), ...
        'VariableNames', {'Method', 'NumImages', 'MeanPrecision', ...
        'MeanRecall', 'MeanF1Score', 'MeanIoU', 'MeanAccuracy', ...
        'MeanRuntimeSec', 'MeanFPS'});

    summary = appendTable(summary, row);
end
end

function y = nanMean(x)
x = x(~isnan(x));
if isempty(x)
    y = NaN;
else
    y = mean(x);
end
end

function t = appendTable(t, row)
if isempty(row)
    return;
end

if isempty(t)
    t = row;
else
    t = [t; row];
end
end

function files = listInputImages(imageDir)
patterns = {'*.jpg', '*.JPG', '*.jpeg', '*.JPEG'};
files = {};
for p = 1:numel(patterns)
    found = dir(fullfile(imageDir, patterns{p}));
    for i = 1:numel(found)
        files{end + 1, 1} = fullfile(found(i).folder, found(i).name); %#ok<AGROW>
    end
end
files = sort(files);
end

function maskPath = findMaskFile(maskDir, baseName)
candidates = { ...
    fullfile(maskDir, [baseName '.png']), ...
    fullfile(maskDir, [baseName '.PNG']), ...
    fullfile(maskDir, [baseName '_mask.png']), ...
    fullfile(maskDir, [baseName '_mask.PNG']), ...
    fullfile(maskDir, [baseName '.jpg']), ...
    fullfile(maskDir, [baseName '.JPG'])};

maskPath = '';
for i = 1:numel(candidates)
    if isfile(candidates{i})
        maskPath = candidates{i};
        return;
    end
end
end

function rgb = toRGB(img)
if ismatrix(img)
    rgb = repmat(img, 1, 1, 3);
elseif size(img, 3) == 4
    rgb = img(:, :, 1:3);
else
    rgb = img;
end
end

function mask = maskToLogical(mask)
if ndims(mask) == 3
    mask = rgb2gray(mask(:, :, 1:3));
end

if islogical(mask)
    return;
end

mask = im2double(mask);
mask = mask > 0.5;
end

function overlay = overlayMask(img, mask, color, alpha)
overlay = im2double(toRGB(img));
mask = maskToLogical(mask);

if ~isequal(size(mask), [size(overlay, 1), size(overlay, 2)])
    mask = imresize(mask, [size(overlay, 1), size(overlay, 2)], 'nearest');
    mask = maskToLogical(mask);
end

for c = 1:3
    channel = overlay(:, :, c);
    channel(mask) = (1 - alpha) * channel(mask) + alpha * color(c);
    overlay(:, :, c) = channel;
end
end

function img = paintMask(img, mask, color)
img = im2double(toRGB(img));
mask = maskToLogical(mask);

for c = 1:3
    channel = img(:, :, c);
    channel(mask) = color(c);
    img(:, :, c) = channel;
end
end

function ensureDir(pathToDir)
if ~isfolder(pathToDir)
    mkdir(pathToDir);
end
end
