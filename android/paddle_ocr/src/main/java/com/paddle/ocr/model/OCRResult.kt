// Copyright (c) 2026 PaddlePaddle Authors. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package com.paddle.ocr.model

data class OCRResult(
    val box: OCRBox,
    val text: String,
    val confidence: Float,
    // Sophis: normalized horizontal recognition positions, one per UTF-16 unit.
    val characterPositions: List<Float> = emptyList(),
    val wordBoxes: List<OCRBox>? = null,
)
