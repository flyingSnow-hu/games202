# cpp 端
 * 完成了 shadowed 和 unshadowed 预计算
 * 增加了 SumIndirectCoeffs 方法用于计算间接光

# webgl 端
 * 增加了 CornellBox 和 Skybox2 两个环境选项
 * 增加了 PrtMaterial 材质
 * 为 PrtMaterial 材质传入了 aPrecomputeLT、uPrecomputeLR、uPrecomputeLG、uPrecomputeLB 参数
 * 完成了 tools.js/getRotationPrecomputeL 函数，实现了球谐函数旋转