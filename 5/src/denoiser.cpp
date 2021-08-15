#include "denoiser.h"

using namespace std;

Denoiser::Denoiser() : m_useTemportal(false) {}

void Denoiser::Reprojection(const FrameInfo &frameInfo) {
    int height = m_accColor.m_height;
    int width = m_accColor.m_width;
    Matrix4x4 preWorldToScreen =
        m_preFrameInfo.m_matrix[m_preFrameInfo.m_matrix.size() - 1];
    Matrix4x4 preWorldToCamera =
        m_preFrameInfo.m_matrix[m_preFrameInfo.m_matrix.size() - 2];
#pragma omp parallel for
    for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
            // TODO: Reproject
            m_valid(x, y) = false;
            m_misc(x, y) = Float3(0.f);
        }
    }
    std::swap(m_misc, m_accColor);
}

void Denoiser::TemporalAccumulation(const Buffer2D<Float3> &curFilteredColor) {
    int height = m_accColor.m_height;
    int width = m_accColor.m_width;
    int kernelRadius = 3;
#pragma omp parallel for
    for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
            // TODO: Temporal clamp
            Float3 color = m_accColor(x, y);
            // TODO: Exponential moving average
            float alpha = 1.0f;
            m_misc(x, y) = Lerp(color, curFilteredColor(x, y), alpha);
        }
    }
    std::swap(m_misc, m_accColor);
}

Buffer2D<Float3> Denoiser::Filter(const FrameInfo &frameInfo) {
    int height = frameInfo.m_beauty.m_height;
    int width = frameInfo.m_beauty.m_width;
    Buffer2D<Float3> filteredImage = CreateBuffer2D<Float3>(width, height);
    int kernelRadius = 16;

#pragma omp parallel for
    for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
            double summedR = 0, summedG = 0, summedB = 0;
            double summedWeightR = 0, summedWeightG = 0, summedWeightB = 0;
            for (int jx = max(x - kernelRadius / 2, 0);
                 jx <= min(x + kernelRadius / 2, width - 1); jx++) {
                for (int jy = max(y - kernelRadius / 2, 0);
                     jy <= min(y + kernelRadius / 2, height - 1); jy++) {
                    auto sqrDist = Sqr(jx - x) + Sqr(jy - y);
                    auto sqrDNormal = Sqr(
                        SafeAcos(
                            Dot(frameInfo.m_normal(x, y), frameInfo.m_normal(jx, jy))
                        )
                    );

                    auto sqrDPlane = Sqr(
                                Dot(frameInfo.m_normal(x, y), 
                                Normalize(frameInfo.m_position(jx, jy) -
                                            frameInfo.m_position(x, y)))
                        );

                    auto sum = -sqrDist / (2 * m_sigmaPlane * m_sigmaPlane)
                                -sqrDNormal / (2 * m_sigmaNormal * m_sigmaNormal) 
                                -sqrDPlane / (2 * m_sigmaCoord * m_sigmaCoord);

                    auto color_i = frameInfo.m_beauty(x, y);
                    auto color_j = frameInfo.m_beauty(jx, jy);
                    auto sqrDistR = Sqr(color_i.x - color_j.x);
                    auto sqrDistG = Sqr(color_i.y - color_j.y);
                    auto sqrDistB = Sqr(color_i.z - color_j.z);
                    double sqrSigmaColor2 = 2 * m_sigmaColor * m_sigmaColor;

                    double weightR = exp(sum - sqrDistR / sqrSigmaColor2);
                    double weightG = exp(sum - sqrDistG / sqrSigmaColor2);
                    double weightB = exp(sum - sqrDistB / sqrSigmaColor2);

                    summedWeightR += weightR;
                    summedWeightG += weightG;
                    summedWeightB += weightB;

                    summedR += color_j.x * weightR;
                    summedG += color_j.y * weightG;
                    summedB += color_j.z * weightB;
                }
            }
            
            filteredImage(x, y) = Float3(summedR/summedWeightR, summedG/summedWeightG, summedB/summedWeightB);
            //filteredImage(x, y) = Float3(summedR, summedG, summedB);
        }
    }
    return filteredImage;
}

void Denoiser::Init(const FrameInfo &frameInfo, const Buffer2D<Float3> &filteredColor) {
    m_accColor.Copy(filteredColor);
    int height = m_accColor.m_height;
    int width = m_accColor.m_width;
    m_misc = CreateBuffer2D<Float3>(width, height);
    m_valid = CreateBuffer2D<bool>(width, height);
}

void Denoiser::Maintain(const FrameInfo &frameInfo) { m_preFrameInfo = frameInfo; }

Buffer2D<Float3> Denoiser::ProcessFrame(const FrameInfo &frameInfo) {
    // Filter current frame
    Buffer2D<Float3> filteredColor;
    filteredColor = Filter(frameInfo);

    // Reproject previous frame color to current
    if (m_useTemportal) {
        Reprojection(frameInfo);
        TemporalAccumulation(filteredColor);
    } else {
        Init(frameInfo, filteredColor);
    }

    // Maintain
    Maintain(frameInfo);
    if (!m_useTemportal) {
        m_useTemportal = true;
    }
    return m_accColor;
}
