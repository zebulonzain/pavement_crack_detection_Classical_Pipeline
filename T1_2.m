img = imread(['/Users/./Documents/MATLAB/capstone project/pavement crack datasets/CRACK500/traincrop/' ...
    '20160222_081011_1281_721.jpg']);

gray = im2double(rgb2gray(img));

heq = histeq(gray);

gray_s = imgaussfilt(gray);
T = graythresh(gray_s); 
mask = ~imbinarize(gray_s, T);
se = strel('disk', 1);
cl01 = adapthisteq(gray,'ClipLimit', 0.02);

% Enhance dark crack-like structures before thresholding.
crack_enhanced = imbothat(gray, strel('disk', 7));
crack_enhanced = mat2gray(crack_enhanced);
crack_enhanced = imadjust(crack_enhanced);


subplot(1,3,1);imshow(gray);title('grayscale');
subplot(1,3,2);imshow(heq);title('heq');
subplot(1,3,3);imshow(cl01);title('CLAHE');

mask = imopen(mask, strel('disk',1));
figure
imshow(mask);

%%
e_def = edge(gray, 'Canny');
med = median(gray(:)); %median heuristic
T_lo = 0.66*med; 
T_hi = 1.33*med;
T_hi = min(T_hi,1);
e_tuned = edge(gray, 'Canny', [T_lo T_hi]);

%ov = repmat(unit8(gray*255),[1 1 3]);
%ov(:,:,1) = ov(:,:,1) + unit8(e_turn)*255;
overlay_c = labeloverlay(gray,e_tuned,...
    'Colormap',[1 0 0]);

pct_def = 100 * nnz(e_def) / numel(e_def);
pct_tuned = 100 * nnz(e_tuned) / numel(e_tuned);
fprintf('Default Canny Edge Pixels : %.2f %%\n',pct_def);
fprintf('Tuned Canny Edge Pixels   : %.2f %%\n',pct_tuned);

figure;
subplot(2,2,1);
imshow(cl01,[]);
title('CLAHE Grayscale');
subplot(2,2,2);
imshow(e_def);
title(sprintf('Default Canny (%.2f%%)',pct_def));
subplot(2,2,3);
imshow(e_tuned);
title(sprintf('Tuned Canny (%.2f%%)',pct_tuned));
subplot(2,2,4);
imshow(overlay_c);
title('Tuned Overlay');



rect = [100 0 500 200]; %[x y w h] - adjust
cropped_image = imcrop(gray,rect);
%figure;imshow(cropped_image);title('crop');

%%
mask_sauv = ~imbinarize(gray,'adaptive','Sensitivity',0.2,'ForegroundPolarity','dark');
mask_sauv = imopen(mask_sauv, strel('disk',1));
figure
imshow(mask_sauv);

%%
overlay = labeloverlay(gray,mask_sauv,...
    'Colormap',[1 0 0]);

figure;
imshow(overlay);
title('Overlay');

w=25; k=0.34; R=0.5;
function mask = sauvolaThreshold(I, w, k, R)
% I in [0,1] double; w odd window; k in 0.2–0.5;
% R = 0.5 for double, 128 for uint8.
m = imboxfilt(I, w);
m2 = imboxfilt(I.^2, w);
s = sqrt(max(m2 - m.^2, 0));
T = m .* (1 + k .* (s./R - 1));
mask = I < T; % cracks darker than local T
end

T = graythresh(gray); mask_otsu = ~imbinarize(gray, T);
mask_otsu = imopen(mask_otsu, strel('disk',1));

mask_sauvola = sauvolaThreshold(gray, w, k, R);
mask_sauvola = imopen(mask_sauvola, strel('disk',1));

mask_dark = crack_enhanced > graythresh(crack_enhanced);
mask_dark = bwareaopen(mask_dark, 35);
mask_dark = imclose(mask_dark, strel('line', 9, 0));
mask_dark = imclose(mask_dark, strel('line', 9, 20));

crack_mask = (mask_sauvola | mask_dark) & imdilate(e_tuned, strel('disk', 4));
crack_mask = imclose(crack_mask, strel('line', 25, 0));
crack_mask = imclose(crack_mask, strel('line', 17, 20));
crack_mask = imfill(crack_mask, 'holes');
crack_mask = bwareaopen(crack_mask, 100);
crack_mask = bwpropfilt(crack_mask, 'MajorAxisLength', [80 Inf]);
figure;
subplot(2,2,1);imshow(gray);title('Grayscale');
subplot(2,2,2);imshow(crack_enhanced);title('Dark-crack enhancement');
subplot(2,2,3);imshow(mask_sauvola);title('Sauvola mask');
subplot(2,2,4);imshow(crack_mask);title('Cleaned crack mask');

skel = bwmorph(crack_mask,'thin', Inf);
junc = bwmorph(skel,'branchpoints'); % 3+ neighbours
ep = bwmorph(skel,'endpoints');
fprintf('Skeleton px: %d\n', nnz(skel));
fprintf('Branch points px: %d\n', nnz(junc));
fprintf('End points px: %d\n', nnz(ep));
pruned = bwpropfilt(skel,'Area',[40 Inf]);

figure;
subplot(2,2,1);imshow(crack_mask);title('Cleaned crack mask');
subplot(2,2,2);imshow(skel);title('skeleton');
subplot(2,2,3);imshow(skel); hold on;
[yj,xj] = find(junc);
plot(xj,yj,'r.','MarkerSize',4)
%[ye,xe] = find(ep);
%plot(xe,ye,'r.','MarkerSize',4);
title('skeleton + junction');
subplot(2,2,4);imshow(pruned);title('pruned skeleton');



mm_per_px = 0.1;
[L,num] = bwlabel(pruned); 
dist = bwdist(~crack_mask); 
stats = regionprops(L,...
    'PixelIdxList',...
    'Orientation',...
    'MajorAxisLength',...
    'Centroid');

length_mm = zeros(num,1);
width_mm = zeros(num,1);
orientation_deg = zeros(num,1);

for k = 1:num

    idx = stats(k).PixelIdxList;

    % Length from skeleton pixels
    length_px = numel(idx);

    length_mm(k) = length_px * mm_per_px;

 % Width from distance transform
    width_px = mean(dist(idx))*2;

    width_mm(k) = width_px * mm_per_px;

    % Orientation
    orientation_deg(k) = stats(k).Orientation;

end

T = table(...
    (1:num)',...
    length_mm,...
    width_mm,...
    orientation_deg,...
    'VariableNames',...
    {'Crack_ID',...
     'Length_mm',...
     'Width_mm',...
     'Orientation_deg'});

T = sortrows(T,'Length_mm','descend');

topN = min(5,height(T));

disp(' ')
fprintf('Top %d Cracks\n', topN)
disp(T(1:topN,:))


%% Display original image

figure
imshow(gray)
hold on

for n = 1:topN

    id = T.Crack_ID(n);

    s = stats(id);

    cx = s.Centroid(1);
    cy = s.Centroid(2);

    theta = deg2rad(-s.Orientation);

    len = s.MajorAxisLength/2;

    x1 = cx - len*cos(theta);
    x2 = cx + len*cos(theta);

    y1 = cy - len*sin(theta);
    y2 = cy + len*sin(theta);

    line([x1 x2],[y1 y2],...
        'Color','r',...
        'LineWidth',2)

    text(cx,cy,...
        sprintf('%d',id),...
        'Color','y',...
        'FontSize',12,...
        'FontWeight','bold');
end

title(sprintf('Top-%d Crack Orientations', topN))

output_dir = fileparts(mfilename('fullpath'));
imwrite(crack_mask, fullfile(output_dir, 'T1_2_crack_mask.png'));
exportgraphics(gcf, fullfile(output_dir, 'T1_2_result.png'), ...
    'Resolution', 200);
