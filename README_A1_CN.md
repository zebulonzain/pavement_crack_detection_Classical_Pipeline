# ELEC9773 A1 Classical Pipeline 精简版

这个文件夹是专门为 Week 5 A1 Progress Report 准备的传统图像处理版本，不包含 U-Net。

目标是完成并展示：

- CRACK500 图像读取
- 多尺度归一化
- Gaussian 去噪
- CLAHE 局部对比度增强
- Otsu 对照实验
- Sauvola 主分割算法
- Canny 展示实验
- Morphological opening / small object removal
- Skeleton 骨架化
- Spur pruning 毛刺剪枝
- Length / width / orientation 几何测量
- Precision / Recall / F1 / IoU 定量评估
- A1 报告可直接使用的结果图和 CSV 表格

## 1. 最简文件结构

```text
ELEC9773_A1_Classical_Pipeline/
├── A1_prepare_crack500_simple.m
├── A1_run_classical_pipeline.m
├── README_A1_CN.md
├── data/
│   ├── images/    # 放 CRACK500 原图 jpg
│   └── masks/     # 放同名 ground truth png
└── results/       # 自动输出结果图和 CSV
```

只需要记住两句话：

```text
jpg 原图 -> data/images
png 标签 -> data/masks
```

例如：

```text
data/images/20160328_153524_1281_361.jpg
data/masks/20160328_153524_1281_361.png
```

## 2. 自动整理 CRACK500

如果你的 CRACK500 下载目录里有这些文件夹：

```text
traincrop/
valcrop/
testcrop/
```

打开：

```matlab
A1_prepare_crack500_simple.m
```

把第一行路径改成你的 CRACK500 根目录：

```matlab
sourceRoot = '/Users/你的用户名/Downloads/CRACK500';
```

然后运行：

```matlab
run('A1_prepare_crack500_simple.m')
```

它会自动把 crop 文件夹中成对的：

```text
*.jpg -> data/images
*.png -> data/masks
```

复制到本 A1 项目里。

## 3. 运行 A1 经典流水线

在 MATLAB 当前目录切到本文件夹：

```matlab
cd /path/to/ELEC9773_A1_Classical_Pipeline
```

然后运行：

```matlab
run('A1_run_classical_pipeline.m')
```

默认处理前 20 张图。要改数量，打开脚本顶部修改：

```matlab
cfg.maxImages = 20;
```

如果想处理全部：

```matlab
cfg.maxImages = Inf;
```

## 4. 输出文件说明

运行后，`results/` 里会生成：

```text
method_metrics.csv
```

每张图、每种方法的 Precision / Recall / F1 / IoU / runtime / FPS。

```text
summary_metrics.csv
```

Otsu、Sauvola、Canny 的平均指标，适合直接放 A1 报告。

```text
crack_component_features.csv
```

每个连通裂缝分量的 Length / Mean Width / Max Width / Orientation。

```text
top5_crack_features.csv
```

长度最大的前 5 个裂缝分量，适合放报告表格。

```text
multiscale_metrics.csv
```

不同缩放分辨率下的 Sauvola 指标和运行速度，用于 Multi-scale Analysis。

每张图还会输出：

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

## 5. A1 报告推荐使用方式

### Methodology

放这条流程：

```text
Input
↓
Resize to 640x480
↓
Gray
↓
Gaussian
↓
CLAHE
↓
Sauvola
↓
Morphology
↓
Skeleton
↓
Spur pruning
↓
Length / width / orientation
```

### Experimental Results

推荐放：

- 一张 `*_four_panel.png`
- 一张 `*_otsu_mask.png` vs `*_sauvola_mask.png`
- `summary_metrics.csv` 的平均表
- `multiscale_metrics.csv` 的速度对比
- `top5_crack_features.csv` 的裂缝几何表

### Discussion

重点写：

- Otsu 使用全局阈值，阴影和湿路面下容易把暗背景误判成裂缝。
- Canny 是边缘检测，不是真正的像素级 segmentation，因此只能作为展示实验。
- Sauvola 使用局部均值和局部标准差，对光照不均更稳。
- Skeleton + distance transform 可以把分割结果转成工程上有意义的 length / width / orientation。

## 6. 参数建议

脚本顶部常用参数：

```matlab
cfg.targetSize = [480 640];
cfg.gaussianSigma = 1.0;
cfg.claheClipLimit = 0.02;
cfg.sauvolaWindowSize = [31 31];
cfg.sauvolaK = 0.34;
cfg.minObjectArea = 50;
cfg.spurPruneIterations = 20;
```

如果误检很多：

```matlab
cfg.minObjectArea = 80;
cfg.sauvolaK = 0.28;
```

如果漏检细裂缝：

```matlab
cfg.sauvolaK = 0.40;
cfg.minObjectArea = 30;
```
