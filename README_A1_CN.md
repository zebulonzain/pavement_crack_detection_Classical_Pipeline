# Classical Image Processing Pipeline for Crack Detection

# 裂缝检测传统图像处理流程

It does not include any deep learning models such as U-Net.

主要展示传统图像处理方法，不包含 U-Net 等深度学习模型。

## 1. Project Objective

## 1. 项目目标

The aim of this pipeline is to detect pavement cracks from CRACK500 images 

本项目目标是基于 CRACK500 图像实现路面裂缝检测

The pipeline includes:

本流程包括：

```text
Image loading
Multi-scale resizing
Gaussian denoising
CLAHE contrast enhancement
Otsu thresholding
Sauvola adaptive segmentation
Canny edge detection
Morphological post-processing
Skeletonization
Spur pruning
Length, width, and orientation measurement
Precision, Recall, F1-score, and IoU evaluation
```

```text
图像读取
多尺度缩放
Gaussian 去噪
CLAHE 局部对比度增强
Otsu 阈值分割
Sauvola 自适应分割
Canny 边缘检测
形态学后处理
骨架化
毛刺剪枝
长度、宽度和方向测量
Precision、Recall、F1-score 和 IoU 定量评估
```

## 2. Folder Structure

## 2. 文件结构

```text
ELEC9773_A1_Classical_Pipeline/
├── A1_prepare_crack500_simple.m
├── A1_run_classical_pipeline.m
├── README_A1_CN.md
├── data/
│   ├── images/    # CRACK500 original images
│   └── masks/     # Ground truth masks
└── results/       # Output figures and CSV files
```

The input images and ground truth masks should be placed as follows:

原始图像和标签文件应按如下方式放置：

```text
data/images/xxx.jpg
data/masks/xxx.png
```

For example:

例如：

```text
data/images/20160328_153524_1281_361.jpg
data/masks/20160328_153524_1281_361.png
```

## 3. Preparing the CRACK500 Dataset

## 3. 整理 CRACK500 数据集

If the CRACK500 dataset contains the following folders:

如果 CRACK500 数据集中包含以下文件夹：

```text
traincrop/
valcrop/
testcrop/
```

open the script:

打开脚本：

```matlab
A1_prepare_crack500_simple.m
```

and modify the dataset path:

并修改数据集路径：

```matlab
sourceRoot = '/Users/your_username/Downloads/CRACK500';
```

Then run:

然后运行：

```matlab
run('A1_prepare_crack500_simple.m')
```

The script will copy matched image and mask pairs into:

该脚本会自动将匹配的图像和标签复制到：

```text
data/images/
data/masks/
```

## 4. Running the Classical Pipeline

## 4. 运行传统图像处理流程

Set the MATLAB current folder to this project directory:

将 MATLAB 当前目录切换到本项目文件夹：

```matlab
cd /path/to/ELEC9773_A1_Classical_Pipeline
```

Then run:

然后运行：

```matlab
run('A1_run_classical_pipeline.m')
```

By default, the script processes the first 20 images. This can be changed at the top of the script:

默认处理前 20 张图像，可在脚本顶部修改：

```matlab
cfg.maxImages = 20;
```

To process all images:

如需处理全部图像：

```matlab
cfg.maxImages = Inf;
```

## 5. Output Files

## 5. 输出文件

After running the pipeline, the following files will be generated in the `results/` folder:

运行后，`results/` 文件夹中会生成以下文件：

```text
method_metrics.csv
```

Per-image evaluation results, including Precision, Recall, F1-score, IoU, runtime, and FPS.

每张图像的评价结果，包括 Precision、Recall、F1-score、IoU、运行时间和 FPS。

```text
summary_metrics.csv
```

Average performance of Otsu, Sauvola, and Canny methods.

Otsu、Sauvola 和 Canny 方法的平均性能指标。

```text
crack_component_features.csv
```

Geometric features of each connected crack component, including length, mean width, maximum width, and orientation.

每个裂缝连通区域的几何特征，包括长度、平均宽度、最大宽度和方向。

```text
top5_crack_features.csv
```

The top five longest crack components, suitable for report tables.

长度最大的前五个裂缝分量，适合用于报告表格。

```text
multiscale_metrics.csv
```

Sauvola performance and runtime under different image scales.

不同图像缩放尺度下 Sauvola 方法的性能和运行时间。

The pipeline also generates result figures such as:

同时也会生成以下结果图：

```text
*_four_panel.png
*_overlay.png
*_otsu_mask.png
*_sauvola_mask.png
*_canny.png
*_skeleton_raw.png
*_skeleton_pruned.png
*_junctions.png
```
