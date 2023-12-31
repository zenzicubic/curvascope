/**
 * This is the fragment shader, responsible for rendering the tiling.
 * This code is protected under the MIT license (see the LICENSE file).
 * Author: Zenzicubic
 */

uniform vec2 resolution;
uniform float time;
uniform float scale;

// Tiling parameters
uniform vec2 invCen;
uniform vec2 refNrm;
uniform vec2 mousePos;
uniform float invRad;

// Appearance settings
uniform vec3 tileCol;
uniform int modelIdx;
uniform bool doEdges;
uniform bool doSolidColor;
uniform bool doParity;

// Rendering settings
uniform int nSamples;
uniform float invSamples;
uniform int nIterations;

out vec4 outputCol;

#define BG_COLOR vec3(.07)
#define THICKNESS .01
#define COLOR_COEFF 3.
#define PARITY_COEFF .6

/*
Complex utility functions and transformations.
*/

#define CMP_I vec2(0., 1.)
#define CMP_ONE vec2(1., 0.)

float normSq(vec2 v) { return dot(v, v); } // Squared norm of a vector

vec2 cinv(vec2 z) {
    // Complex reciprocal
    return vec2(z.x, -z.y) / normSq(z);
}

vec2 cmul(vec2 a, vec2 b) {
    // Complex number multiplication
    return vec2(a.x * b.x - a.y * b.y, a.x * b.y + a.y * b.x);
}

vec2 cdiv(vec2 a, vec2 b) {
    // Complex number division
    return cmul(a, cinv(b)); 
}

vec2 cexp(vec2 z) { 
    // Complex exponential
    return vec2(cos(z.y), sin(z.y)) * exp(z.x);
}

vec2 ctanh(vec2 z) {
    // Complex hyperbolic tangent
    z = cexp(2. * z);
    return cdiv(z - CMP_ONE, z + CMP_ONE);
}

#define PI 3.14159265358
#define MAP_SCALE 3.
#define GANS_SCALE 10.

vec2 remapToDisk(vec2 z) {
    // Remaps the point from the given model to the Poincare disk
    switch (modelIdx) {
        case 1:
            // Half-plane model
            z.y++;
            return cdiv(z - CMP_I, z + CMP_I);
        case 2:
            // Klein model
            return z / (1. + sqrt(1. - normSq(z)));
        case 3:
            // Inverted Poincare disk model
            return cinv(z * MAP_SCALE);
        case 4:
            // Gans model
            z *= GANS_SCALE;
            return z / (1. + sqrt(1. + normSq(z)));
        case 5:
            // Azimuthal equidistant projection
            z *= MAP_SCALE;
            float len = tanh(.5 * length(z));
            return normalize(z) * len;
        case 6:
            // Equal-area projection
            z *= MAP_SCALE;
            return z / sqrt(1. + normSq(z));
        case 7:
            // Band model
            return ctanh(z);
    }
    return z;
}

vec2 shift(vec2 z, vec2 a) {
    // Transform point in unit disk
    return cdiv(z - a, vec2(1., 0.) - cmul(z, a * vec2(1., -1.)));
}

/*
The coloring function.
*/

#define invRadSq invRad * invRad

vec3 tilingSample(vec2 pt) {
    // Remap point to screen and move it around
    vec2 z = (2. * pt - resolution) / scale;
    z = remapToDisk(z);

    if (dot(z, z) > 1.) return BG_COLOR;
    z = shift(z, mousePos);
    
    // Repeatedly invert and reflect until we are within the fundamental domain
    bool fund;
    float distSq, dotProd;
    vec2 diff;
    float n = 0.;
    for (int i = 0; i < nIterations; i ++) {
        fund = true;

        // Edge
        diff = z - invCen;
        distSq = normSq(diff);
        if (distSq < invRadSq) {
            fund = false;
            z = invCen + (invRadSq * diff) / distSq;
            n ++;
        }

        // Sectional line
        dotProd = dot(z, refNrm);
        if (dotProd < 0.) {
            fund = false;
            z -= 2. * dotProd * refNrm;
            n ++;
        }

        // Edge bisector
        if (z.y < 0.) {
            fund = false;
            z.y *= -1.;
            n ++;
        }
        
        if (fund) break; // We are in the fundamental domain; no need to keep going
    }
    
    // Distance to the tile edge
    float brt = 1.;
    if (doEdges) {
        brt = distance(z, invCen) - invRad;
        brt = step(THICKNESS, brt);
    } 

    // Show parity
    if (doParity)
        brt = min(brt, mix(1., mod(n, 2.), PARITY_COEFF));

    // Coloring
    vec3 texCol = tileCol;
    if (!doSolidColor) {
        float t = COLOR_COEFF * z.x - time;
        texCol = .5 + .5 * cos(6.283 * (t + vec3(0, .1, .2)));
    }
    return brt * texCol;
}

/*
Antialiasing and output.
*/

void main(void) {
    vec2 pt = gl_FragCoord.xy;

    // Antialiasing
    vec3 color;
    if (nSamples > 1) {
        vec2 diff;
        for (int i = 0; i < nSamples; i ++) {
            for (int j = 0; j < nSamples; j ++) {
                diff = vec2(
                    float(i) * invSamples - .5, 
                    float(j) * invSamples - .5);
                color += tilingSample(pt + diff);
            }
        }
        color *= invSamples * invSamples;
    } else {
        color = tilingSample(pt);
    }

    outputCol = vec4(color, 1.);
}