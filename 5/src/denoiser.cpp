#include "denoiser.h"

using namespace std;
typedef Float3::EType EType;

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
            m_valid(x, y) = false;
            m_misc(x, y) = Float3(0.f);

            auto objectId = frameInfo.m_id(x, y);
            if (objectId < 0)
                continue;
            
            auto crntWorldPos = frameInfo.m_position(x, y);
            auto objectPos = (Inverse(frameInfo.m_matrix[objectId]))(crntWorldPos, EType::Point);
            auto lastWorldPos = m_preFrameInfo.m_matrix[objectId](objectPos, EType::Point);

            auto lastScreenPos = preWorldToScreen(lastWorldPos, EType::Point);

            bool isValid = lastScreenPos.x >= 0 && lastScreenPos.x < width &&
                           lastScreenPos.y >= 0 && lastScreenPos.y < height && 
                            m_preFrameInfo.m_id(lastScreenPos.x, lastScreenPos.y) == objectId;
            

            if (isValid) {
                m_valid(x, y) = true;
                m_misc(x, y) = m_accColor(lastScreenPos.x, lastScreenPos.y);
            }
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
            if (m_valid(x, y) == false) {
                m_misc(x, y) = curFilteredColor(x, y);
                continue;
            }

            // TODO: Temporal clamp
            Float3 color = m_accColor(x, y);
            // TODO: Exponential moving average
            int count = 0;
            double summedSqrR = 0, summedSqrG = 0, summedSqrB = 0;
            double summedR = 0, summedG = 0, summedB = 0;
            for (int xx = max(0, x - kernelRadius); xx  <= min(width - 1, x + kernelRadius); xx ++) {
                for (int yy = max(0, y - kernelRadius); yy <= min(height - 1, y + kernelRadius); yy++) {
                    Float3 cc = curFilteredColor(xx, yy);
                    summedSqrR += Sqr(cc.x);
                    summedSqrG += Sqr(cc.y);
                    summedSqrB += Sqr(cc.z);

                    summedR += cc.x;
                    summedG += cc.y;
                    summedB += cc.z;

                    count++;
                }
            }
            float eR = summedR / count, eG = summedG / count, eB = summedB / count;
            float vR = max(summedSqrR / count - eR * eR, 0.0);
            float vG = max(summedSqrG / count - eG * eG, 0.0);
            float vB = max(summedSqrB / count - eB * eB, 0.0);

            float clampedR = clamp(color.x , eR - m_colorBoxK * vR, eR + m_colorBoxK * vR);
            float clampedG = clamp(color.y , eG - m_colorBoxK * vG, eG + m_colorBoxK * vG);
            float clampedB = clamp(color.z , eB - m_colorBoxK * vB, eB + m_colorBoxK * vB);

            m_misc(x, y) = Lerp(Float3(clampedR, clampedG, clampedB), curFilteredColor(x, y), m_alpha);
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
            for (int jx = max(x - kernelRadius, 0);
                 jx <= min(x + kernelRadius, width - 1); jx++) {
                for (int jy = max(y - kernelRadius, 0);
                     jy <= min(y + kernelRadius, height - 1); jy++) {
                    double weightR = 1;
                    double weightG = 1;
                    double weightB = 1;
                    auto color_i = frameInfo.m_beauty(x, y);
                    auto color_j = frameInfo.m_beauty(jx, jy);

                    if (x != jx || y != jy) {
                        auto sqrDist = Sqr(jx - x) + Sqr(jy - y);
                        auto sqrDNormal = Sqr(SafeAcos(
                            Dot(frameInfo.m_normal(x, y), frameInfo.m_normal(jx, jy))));

                        auto sqrDPlane = Sqr(Dot(frameInfo.m_normal(x, y),
                                                 Normalize(frameInfo.m_position(jx, jy) -
                                                           frameInfo.m_position(x, y))));

                        auto sum = -sqrDist / (2 * m_sigmaCoord * m_sigmaCoord) -
                                   sqrDNormal / (2 * m_sigmaNormal * m_sigmaNormal) -
                                   sqrDPlane / (2 * m_sigmaPlane * m_sigmaPlane);

                        auto sqrDistR = Sqr(color_i.x - color_j.x);
                        auto sqrDistG = Sqr(color_i.y - color_j.y);
                        auto sqrDistB = Sqr(color_i.z - color_j.z);

                        double sqrSigmaColor2 = 2 * m_sigmaColor * m_sigmaColor;

                        weightR = exp(sum - sqrDistR / sqrSigmaColor2);
                        weightG = exp(sum - sqrDistG / sqrSigmaColor2);
                        weightB = exp(sum - sqrDistB / sqrSigmaColor2);
                    }

                    summedWeightR += weightR;
                    summedWeightG += weightG;
                    summedWeightB += weightB;

                    summedR += color_j.x * weightR;
                    summedG += color_j.y * weightG;
                    summedB += color_j.z * weightB;
                }
            }
            
            filteredImage(x, y) = Float3(summedR/summedWeightR, summedG/summedWeightG, summedB/summedWeightB);
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

Buffer2D<Float3> Denoiser::ProcessFrame(const FrameInfo &frameInfo, const int &i) {
    // Filter current frame
    Buffer2D<Float3> filteredColor;
    filteredColor = Filter(frameInfo);

    // Reproject previous frame color to current
    if (i > 0 && m_useTemportal) {
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
