class PrtMaterial extends Material {

    constructor(color, specular, light, translate, scale, vertexShader, fragmentShader) {
        let lightIntensity = light.mat.GetIntensity();

        super({                    
            'uPrecomputeLR': { type: 'updatedInRealTime', value: null },   
            'uPrecomputeLG': { type: 'updatedInRealTime', value: null },   
            'uPrecomputeLB': { type: 'updatedInRealTime', value: null },   
        }, ['aPrecomputeLT'], vertexShader, fragmentShader, null);
    }
}

async function buildPrtMaterial(color, specular, light, translate, scale, vertexPath, fragmentPath) {
    let vertexShader = await getShaderString(vertexPath);
    let fragmentShader = await getShaderString(fragmentPath);

    return new PrtMaterial(color, specular, light, translate, scale, vertexShader, fragmentShader);

}