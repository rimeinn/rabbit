/*******************************************************************************
 * @description
 * A simple Direct2D wrapper for ahk v2
 *
 * Some code are adapted from this project: [Spawnova/ShinsOverlayClass - MIT License](https://github.com/Spawnova/ShinsOverlayClass)
 *
 * @link https://github.com/rawbx/AHK-Direct2D
 * @file Direct2D.ahk
 * @license MIT
 * @author rawbx
 * @version 0.1.7
 * @example
 * ui := Gui("-DPIScale")
 * d2d := Direct2D()
 * d2d.SetTargetRender(ui.Hwnd, 512, 512)
 * ui.Show("W512 H512")
 * d2d.BeginDraw()
 * d2d.DrawSvg('<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" ...</svg>', 10, 10, 128, 128)
 * d2d.EndDraw()
 ******************************************************************************/
class Direct2D {
    __New(target?) {
        this.erase_background_callback := 0
        this.erase_background_hwnd := 0
        this.gdipToken := this.GdipStartUp() ; to get image bitmap info

        this.isDrawing := 0
        this.clipDepth := 0
        this.textFormats := Map()
        this.solidBrushes := Map()
        this.strokeStyles := Map()
        this.gradientStops := Map()
        this.d2dBitmaps := Map()

        this.colorPrps := Buffer(16, 0)
        this.pointPrps := Buffer(16, 0)
        this.bmpDstRect := Buffer(16, 0)
        this.bmpSrcRect := Buffer(16, 0)
        this.drawBoundsPrps := Buffer(24, 0)
        this.strokeStylePrps := Buffer(28, 0)
        this.textMetricPrps := Buffer(36, 0)
        this.d2dBmpPrps := Buffer(64, 0)
        this.winInfoPrps := Buffer(64, 0)

        this.ID2D1Factory := Direct2D.ID2D1Factory()
        this.IDWriteFactory := Direct2D.IDWriteFactory()

        if isSet(target)
            this.SetRenderTarget(target)
    }

    __Delete() {
        this.UnregisterEraseBackgroundHandler()

        for _, pBrush in this.solidBrushes
            Direct2D.release(pBrush)
        for _, pTextFormat in this.textFormats
            Direct2D.release(pTextFormat)
        for _, pStrokeStyle in this.strokeStyles
            Direct2D.release(pStrokeStyle)
        for _, pGradientStops in this.gradientStops
            Direct2D.release(pGradientStops)
        for _, pBitmap in this.d2dBitmaps
            if pBitmap
                Direct2D.release(pBitmap)

        this.IDWriteFactory := ""
        this.ID2D1Factory := ""
        this.GdipShutdown(this.gdipToken)
    }

    static isX64 := A_PtrSize == 8
    static DWRITE_READING_DIRECTION_LEFT_TO_RIGHT := 0
    static DWRITE_READING_DIRECTION_RIGHT_TO_LEFT := 1
    static DWRITE_READING_DIRECTION_TOP_TO_BOTTOM := 2
    static DWRITE_READING_DIRECTION_BOTTOM_TO_TOP := 3
    static DWRITE_FLOW_DIRECTION_TOP_TO_BOTTOM := 0
    static DWRITE_FLOW_DIRECTION_BOTTOM_TO_TOP := 1
    static DWRITE_FLOW_DIRECTION_LEFT_TO_RIGHT := 2
    static DWRITE_FLOW_DIRECTION_RIGHT_TO_LEFT := 3
    static D2DERR_RECREATE_TARGET := 0x8899000C
    static vTable(p, i) => (v := NumGet(p + 0, 0, "ptr")) ? NumGet(v + 0, i * A_PtrSize, "Ptr") : 0
    static release(p) => (r := this.vTable(p, 2)) ? DllCall(r, "ptr", p) : 0
    static str2guid(guid) => (clsid := Buffer(16, 0), DllCall("ole32\CLSIDFromString", "WStr", guid, "Ptr", clsid), clsid)
    static IsRecreateTarget(hr) => (hr & 0xFFFFFFFF) == this.D2DERR_RECREATE_TARGET
    static SuppressEraseBackground(target_hwnd, wParam, lParam, msg, hwnd) => target_hwnd == hwnd ? 0 : ""

    static ThrowHResult(operation, hr) {
        throw Error(Format("{} failed (HRESULT 0x{:08X})", operation, hr & 0xFFFFFFFF))
    }
    static guid := Map(
        'REFIID_D2DFactory',  Direct2D.str2guid('{06152247-6f50-465a-9245-118bfd3b6007}'),
        'REFIID_DWriteFactory',  Direct2D.str2guid('{B859EE5A-D838-4B5B-A2E8-1ADC7D93DB48}'),
        ; imagingWic
        'GUID_WICPixelFormat32bppBGRA', Direct2D.str2guid('{6fddc324-4e03-4bfe-b185-3d77768dc90f}'),
        'GUID_WICPixelFormat32bppPBGRA', Direct2D.str2guid('{6fddc324-4e03-4bfe-b185-3d77768dc910}'),
        ; built-in effects
        'CLSID_D2D12DAffineTransform', Direct2D.str2guid('{6aa97485-6354-4cfc-908c-e4a74f62c96c}'),
        'CLSID_D2D13DPerspectiveTransform', Direct2D.str2guid('{c2844d0b-3d86-46e7-85ba-526c9240f3fb}'),
        'CLSID_D2D13DTransform', Direct2D.str2guid('{e8467b04-ec61-4b8a-b5de-d4d73debea5a}'),
        'CLSID_D2D1ArithmeticComposite', Direct2D.str2guid('{fc151437-049a-4784-a24a-f1c4daf20987}'),
        'CLSID_D2D1Atlas', Direct2D.str2guid('{913e2be4-fdcf-4fe2-a5f0-2454f14ff408}'),
        'CLSID_D2D1BitmapSource', Direct2D.str2guid('{5fb6c24d-c6dd-4231-9404-50f4d5c3252d}'),
        'CLSID_D2D1Blend', Direct2D.str2guid('{81c5b77b-13f8-4cdd-ad20-c890547ac65d}'),
        'CLSID_D2D1Border', Direct2D.str2guid('{2a2d49c0-4acf-43c7-8c6a-7c4a27874d27}'),
        'CLSID_D2D1Brightness', Direct2D.str2guid('{8cea8d1e-77b0-4986-b3b9-2f0c0eae7887}'),
        'CLSID_D2D1ColorManagement', Direct2D.str2guid('{1a28524c-fdd6-4aa4-ae8f-837eb8267b37}'),
        'CLSID_D2D1ColorMatrix', Direct2D.str2guid('{921f03d6-641c-47df-852d-b4bb6153ae11}'),
        'CLSID_D2D1Composite', Direct2D.str2guid('{48fc9f51-f6ac-48f1-8b58-3b28ac46f76d}'),
        'CLSID_D2D1ConvolveMatrix', Direct2D.str2guid('{407f8c08-5533-4331-a341-23cc3877843e}'),
        'CLSID_D2D1Crop', Direct2D.str2guid('{e23f7110-0e9a-4324-af47-6a2c0c46f35b}'),
        'CLSID_D2D1DirectionalBlur', Direct2D.str2guid('{174319a6-58e9-49b2-bb63-caf2c811a3db}'),
        'CLSID_D2D1DiscreteTransfer', Direct2D.str2guid('{90866fcd-488e-454b-af06-e5041b66c36c}'),
        'CLSID_D2D1DisplacementMap', Direct2D.str2guid('{edc48364-0417-4111-9450-43845fa9f890}'),
        'CLSID_D2D1DistantDiffuse', Direct2D.str2guid('{3e7efd62-a32d-46d4-a83c-5278889ac954}'),
        'CLSID_D2D1DistantSpecular', Direct2D.str2guid('{428c1ee5-77b8-4450-8ab5-72219c21abda}'),
        'CLSID_D2D1DpiCompensation', Direct2D.str2guid('{6c26c5c7-34e0-46fc-9cfd-e5823706e228}'),
        'CLSID_D2D1Flood', Direct2D.str2guid('{61c23c20-ae69-4d8e-94cf-50078df638f2}'),
        'CLSID_D2D1GammaTransfer', Direct2D.str2guid('{409444c4-c419-41a0-b0c1-8cd0c0a18e42}'),
        'CLSID_D2D1GaussianBlur', Direct2D.str2guid('{1feb6d69-2fe6-4ac9-8c58-1d7f93e7a6a5}'),
        'CLSID_D2D1Scale', Direct2D.str2guid('{9daf9369-3846-4d0e-a44e-0c607934a5d7}'),
        'CLSID_D2D1Histogram', Direct2D.str2guid('{881db7d0-f7ee-4d4d-a6d2-4697acc66ee8}'),
        'CLSID_D2D1HueRotation', Direct2D.str2guid('{0f4458ec-4b32-491b-9e85-bd73f44d3eb6}'),
        'CLSID_D2D1LinearTransfer', Direct2D.str2guid('{ad47c8fd-63ef-4acc-9b51-67979c036c06}'),
        'CLSID_D2D1LuminanceToAlpha', Direct2D.str2guid('{41251ab7-0beb-46f8-9da7-59e93fcce5de}'),
        'CLSID_D2D1Morphology', Direct2D.str2guid('{eae6c40d-626a-4c2d-bfcb-391001abe202}'),
        'CLSID_D2D1OpacityMetadata', Direct2D.str2guid('{6c53006a-4450-4199-aa5b-ad1656fece5e}'),
        'CLSID_D2D1PointDiffuse', Direct2D.str2guid('{b9e303c3-c08c-4f91-8b7b-38656bc48c20}'),
        'CLSID_D2D1PointSpecular', Direct2D.str2guid('{09c3ca26-3ae2-4f09-9ebc-ed3865d53f22}'),
        'CLSID_D2D1Premultiply', Direct2D.str2guid('{06eab419-deed-4018-80d2-3e1d471adeb2}'),
        'CLSID_D2D1Saturation', Direct2D.str2guid('{5cb2d9cf-327d-459f-a0ce-40c0b2086bf7}'),
        'CLSID_D2D1Shadow', Direct2D.str2guid('{c67ea361-1863-4e69-89db-695d3e9a5b6b}'),
        'CLSID_D2D1SpotDiffuse', Direct2D.str2guid('{818a1105-7932-44f4-aa86-08ae7b2f2c93}'),
        'CLSID_D2D1SpotSpecular', Direct2D.str2guid('{edae421e-7654-4a37-9db8-71acc1beb3c1}'),
        'CLSID_D2D1TableTransfer', Direct2D.str2guid('{5bf818c3-5e43-48cb-b631-868396d6a1d4}'),
        'CLSID_D2D1Tile', Direct2D.str2guid('{b0784138-3b76-4bc5-b13b-0fa2ad02659f}'),
        'CLSID_D2D1Turbulence', Direct2D.str2guid('{cf2bb6ae-889a-4ad7-ba29-a2fd732c9fc9}'),
        'CLSID_D2D1UnPremultiply', Direct2D.str2guid('{fb9ac489-ad8d-41ed-9999-bb6347d110f7}'),
        'CLSID_D2D1YCbCr', Direct2D.str2guid('{99503cc1-66c7-45c9-a875-8ad8a7914401}'),
        'CLSID_D2D1Contrast', Direct2D.str2guid('{b648a78a-0ed5-4f80-a94a-8e825aca6b77}'),
        'CLSID_D2D1RgbToHue', Direct2D.str2guid('{23f3e5ec-91e8-4d3d-ad0a-afadc1004aa1}'),
        'CLSID_D2D1HueToRgb', Direct2D.str2guid('{7b78a6bd-0141-4def-8a52-6356ee0cbdd5}'),
        'CLSID_D2D1ChromaKey', Direct2D.str2guid('{74c01f5b-2a0d-408c-88e2-c7a3c7197742}'),
        'CLSID_D2D1Emboss', Direct2D.str2guid('{b1c5eb2b-0348-43f0-8107-4957cacba2ae}'),
        'CLSID_D2D1Exposure', Direct2D.str2guid('{b56c8cfa-f634-41ee-bee0-ffa617106004}'),
        'CLSID_D2D1Grayscale', Direct2D.str2guid('{36dde0eb-3725-42e0-836d-52fb20aee644}'),
        'CLSID_D2D1Invert', Direct2D.str2guid('{e0c3784d-cb39-4e84-b6fd-6b72f0810263}'),
        'CLSID_D2D1Posterize', Direct2D.str2guid('{2188945e-33a3-4366-b7bc-086bd02d0884}'),
        'CLSID_D2D1Sepia', Direct2D.str2guid('{3a1af410-5f1d-4dbe-84df-915da79b7153}'),
        'CLSID_D2D1Sharpen', Direct2D.str2guid('{c9b887cb-c5ff-4dc5-9779-273dcf417c7d}'),
        'CLSID_D2D1Straighten', Direct2D.str2guid('{4da47b12-79a3-4fb0-8237-bbc3b2a4de08}'),
        'CLSID_D2D1TemperatureTint', Direct2D.str2guid('{89176087-8af9-4a08-aeb1-895f38db1766}'),
        'CLSID_D2D1Vignette', Direct2D.str2guid('{c00c40be-5e67-4ca3-95b4-f4b02c115135}'),
        'CLSID_D2D1EdgeDetection', Direct2D.str2guid('{eff583ca-cb07-4aa9-ac5d-2cc44c76460f}'),
        'CLSID_D2D1HighlightsShadows', Direct2D.str2guid('{cadc8384-323f-4c7e-a361-2e2b24df6ee4}'),
        'CLSID_D2D1LookupTable3D', Direct2D.str2guid('{349e0eda-0088-4a79-9ca3-c7e300202020}'),
        'CLSID_D2D1Opacity', Direct2D.str2guid('{811d79a4-de28-4454-8094-c64685f8bd4c}'),
        'CLSID_D2D1AlphaMask', Direct2D.str2guid('{c80ecff0-3fd5-4f05-8328-c5d1724b4f0a}'),
        'CLSID_D2D1CrossFade', Direct2D.str2guid('{12f575e8-4db1-485f-9a84-03a07dd3829f}'),
        'CLSID_D2D1Tint', Direct2D.str2guid('{36312b17-f7dd-4014-915d-ffca768cf211}'),
        'CLSID_D2D1WhiteLevelAdjustment', Direct2D.str2guid('{44a1cadb-6cdd-4818-8ff4-26c1cfe95bdb}'),
        'CLSID_D2D1HdrToneMap', Direct2D.str2guid('{7b0b748d-4610-4486-a90c-999d9a2e2b11}'),
    )
    static fnv1aHash(str) {
        hash := 0x811C9DC5
        prime := 0x01000193
        buf := StrPtr(str)
        len := StrLen(str)
        Loop len {
            c := NumGet(buf, (A_Index - 1) * 2, "UShort")
            hash := (hash ^ c) * prime & 0xFFFFFFFF
        }
        return Format("{:08x}", hash)
    }

    class ID2D1Factory {
        __New() {
            D2D1CreateFactory := DllCall("GetProcAddress", "ptr", DllCall("LoadLibrary", "str", "d2d1.dll", "ptr"), "astr", "D2D1CreateFactory", "ptr")
            if !D2D1CreateFactory
                throw Error("Failed to load D2D1CreateFactory")

            if DllCall(D2D1CreateFactory,
                "uint", 1,
                "Ptr", Direct2D.guid["REFIID_D2DFactory"],
                "uint*", 0,
                "Ptr*", &pFactory := 0
            ) != 0
                throw Error("D2D1CreateFactory failed")

            this.pF := pFactory
            this.VT_GetDesktopDpi := Direct2D.vTable(pFactory, 4)
            this.VT_CreatePathGeometry := Direct2D.vTable(pFactory, 10)
            this.VT_CreateStrokeStyle := Direct2D.vTable(pFactory, 11)
            this.VT_CreateWicBitmapRenderTarget := Direct2D.vTable(pFactory, 13)
            this.VT_CreateHwndRenderTarget := Direct2D.vTable(pFactory, 14)
            this.VT_CreateDCRenderTarget := Direct2D.vTable(pFactory, 16)
        }

        __Delete() {
            if this.pF
                Direct2D.release(this.pF)
        }

        GetDesktopDpi() =>
            (DllCall(this.VT_GetDesktopDpi, "ptr", this.pF, 'float*', &dpiX := 0, 'float*', &dpiY := 0, 'uint'), dpiX)

        CreatePathGeometry() =>
            (DllCall(this.VT_CreatePathGeometry, "ptr", this.pF, "ptr*", &pPathGeometry := 0), pPathGeometry)

        CreateStrokeStyle(styleProps) =>
            (DllCall(this.VT_CreateStrokeStyle, "ptr", this.pF, "ptr", styleProps, "ptr", 0, "uint", 0, "ptr*", &pStrokeStyle := 0), pStrokeStyle)

        CreateWicBitmapRenderTarget(pWICBitmap, rtProps) =>
            (DllCall(this.VT_CreateWicBitmapRenderTarget, "Ptr", this.pF, "Ptr", pWICBitmap, "ptr", rtProps, "Ptr*", &pRenderTarget := 0), pRenderTarget)

        CreateHwndRenderTarget(rtProps, hRtProps) =>
            (DllCall(this.VT_CreateHwndRenderTarget, "Ptr", this.pF, "Ptr", rtProps, "ptr", hRtProps, "Ptr*", &pRenderTarget := 0), pRenderTarget)

        CreateDCRenderTarget(rtProps) =>
            (DllCall(this.VT_CreateDCRenderTarget, "Ptr", this.pF, "Ptr", rtProps, "Ptr*", &pRenderTarget := 0), pRenderTarget)
    }

    class IDWriteFactory {
        __New() {
            DWriteCreateFactory := DllCall("GetProcAddress", "ptr", DllCall("LoadLibrary", "str", "dwrite.dll", "ptr"), "astr", "DWriteCreateFactory", "ptr")
            if !DWriteCreateFactory
                throw Error("Failed to load DWriteCreateFactory")

            if DllCall(DWriteCreateFactory,
                "uint", 0,
                "ptr", Direct2D.guid["REFIID_DWriteFactory"],
                "ptr*", &pWFactory := 0
            ) != 0
                throw Error("DWriteCreateFactory failed")

            this.pWF := pWFactory
            this.VT_CreateTextFormat := Direct2D.vTable(pWFactory, 15)
            this.VT_CreateTextLayout := Direct2D.vTable(pWFactory, 18)
        }

        __Delete() {
            if this.pWF
                Direct2D.release(this.pWF)
        }

        CreateTextFormat(fontName, fontSize, fontWeight := 400, fontStyle := 0, options := 0) {
            local readingDirection := this.GetOption(options, "reading_direction", 0)
            local flowDirection := this.GetOption(options, "flow_direction", 0)
            local textAlignment := this.GetOption(options, "text_alignment", 0)
            local paragraphAlignment := this.GetOption(options, "paragraph_alignment", 0)
            local pTextFormat := 0
            local hr

            this.ValidateTextFormatOptions(
                readingDirection,
                flowDirection,
                textAlignment,
                paragraphAlignment
            )

            hr := DllCall(this.VT_CreateTextFormat, "ptr", this.pWF,
                "wstr", fontName,
                "ptr", 0, ; fontCollection
                "uint", fontWeight, ; DWRITE_FONT_WEIGHT_NORMAL
                "uint", fontStyle, ; DWRITE_FONT_STYLE_NORMAL
                "uint", 5, ; DWRITE_FONT_STRETCH_NORMAL
                "float", fontSize,
                "wstr", "en-us",
                "Ptr*", &pTextFormat,
                "hresult"
            )
            if hr != 0
                Direct2D.ThrowHResult("CreateTextFormat", hr)

            try {
                this.ApplyTextFormatOption(pTextFormat, 3, "text alignment", textAlignment)
                this.ApplyTextFormatOption(pTextFormat, 4, "paragraph alignment", paragraphAlignment)
                this.ApplyTextFormatOption(pTextFormat, 6, "reading direction", readingDirection)
                this.ApplyTextFormatOption(pTextFormat, 7, "flow direction", flowDirection)
            } catch as exception {
                Direct2D.release(pTextFormat)
                throw exception
            }
            return pTextFormat
        }

        CreateTextLayout(text, pTextFormat, maxWidth := A_ScreenWidth, maxHeight := A_ScreenHeight, options := 0) {
            local readingDirection := this.GetOption(options, "reading_direction", 0)
            local flowDirection := this.GetOption(options, "flow_direction", 0)
            local pTextLayout := 0
            local hr := DllCall(this.VT_CreateTextLayout, "ptr", this.pWF,
                "wstr", text,
                "uint", StrLen(text),
                "ptr", pTextFormat,
                "float", maxWidth,
                "float", maxHeight,
                "ptr*", &pTextLayout,
                "hresult"
            )
            if hr != 0
                Direct2D.ThrowHResult("CreateTextLayout", hr)
            try {
                this.ValidateTextFormatOptions(readingDirection, flowDirection, 0, 0)
                this.ApplyTextFormatOption(pTextLayout, 6, "layout reading direction", readingDirection)
                this.ApplyTextFormatOption(pTextLayout, 7, "layout flow direction", flowDirection)
            } catch as exception {
                Direct2D.release(pTextLayout)
                throw exception
            }
            return pTextLayout
        }

        GetTextLayoutMetrics(pTextLayout, textMetricPrps) {
            local hr := DllCall(Direct2D.vTable(pTextLayout, 60), ; IDWriteTextLayout::GetMetrics
                "ptr", pTextLayout,
                "ptr", textMetricPrps,
                "hresult"
            )
            if hr != 0
                Direct2D.ThrowHResult("GetTextLayoutMetrics", hr)

            return {
                left: NumGet(textMetricPrps, 0, "float"),
                top: NumGet(textMetricPrps, 4, "float"),
                width: NumGet(textMetricPrps, 8, "float"),
                width_including_trailing_whitespace: NumGet(textMetricPrps, 12, "float"),
                height: NumGet(textMetricPrps, 16, "float"),
                layout_width: NumGet(textMetricPrps, 20, "float"),
                layout_height: NumGet(textMetricPrps, 24, "float"),
                max_bidi_reordering_depth: NumGet(textMetricPrps, 28, "uint"),
                line_count: NumGet(textMetricPrps, 32, "uint")
            }
        }

        GetTextLayoutLineMetrics(pTextLayout, textMetricPrps) {
            local textMetrics := this.GetTextLayoutMetrics(pTextLayout, textMetricPrps)
            local lineCount := textMetrics.line_count
            local lineMetrics := []
            local lineMetricPrps
            local actualLineCount := 0
            local hr

            if lineCount <= 0
                return lineMetrics

            ; DWRITE_LINE_METRICS is three UINT32 values, two FLOAT values, and one BOOL.
            lineMetricPrps := Buffer(lineCount * 24, 0)
            hr := DllCall(Direct2D.vTable(pTextLayout, 59), ; IDWriteTextLayout::GetLineMetrics
                "ptr", pTextLayout,
                "ptr", lineMetricPrps,
                "uint", lineCount,
                "uint*", &actualLineCount,
                "hresult"
            )
            if hr != 0
                Direct2D.ThrowHResult("GetTextLayoutLineMetrics", hr)

            Loop actualLineCount {
                local offset := (A_Index - 1) * 24
                lineMetrics.Push({
                    length: NumGet(lineMetricPrps, offset, "uint"),
                    trailing_whitespace_length: NumGet(lineMetricPrps, offset + 4, "uint"),
                    newline_length: NumGet(lineMetricPrps, offset + 8, "uint"),
                    height: NumGet(lineMetricPrps, offset + 12, "float"),
                    baseline: NumGet(lineMetricPrps, offset + 16, "float"),
                    is_trimmed: NumGet(lineMetricPrps, offset + 20, "int") != 0
                })
            }
            return lineMetrics
        }

        GetOption(options, name, fallback) {
            if !options
                return fallback
            if !IsObject(options)
                throw TypeError("Text format options must be an object or 0.")
            if options is Map
                return options.Has(name) ? options[name] : fallback
            return HasProp(options, name) ? options.%name% : fallback
        }

        ValidateTextFormatOptions(readingDirection, flowDirection, textAlignment, paragraphAlignment) {
            if !IsInteger(readingDirection) || readingDirection < 0 || readingDirection > 3
                throw ValueError("reading_direction must be a DirectWrite reading direction.")
            if !IsInteger(flowDirection) || flowDirection < 0 || flowDirection > 3
                throw ValueError("flow_direction must be a DirectWrite flow direction.")
            if !IsInteger(textAlignment) || textAlignment < 0 || textAlignment > 3
                throw ValueError("text_alignment must be a DirectWrite text alignment.")
            if !IsInteger(paragraphAlignment) || paragraphAlignment < 0 || paragraphAlignment > 2
                throw ValueError("paragraph_alignment must be a DirectWrite paragraph alignment.")

            readingIsVertical := readingDirection >= 2
            flowIsVertical := flowDirection <= 1
            if readingIsVertical == flowIsVertical
                throw ValueError("reading_direction and flow_direction conflict.")
        }

        ApplyTextFormatOption(pTextFormat, vtableIndex, optionName, value) {
            if !value
                return
            local hr := DllCall(Direct2D.vTable(pTextFormat, vtableIndex),
                "ptr", pTextFormat,
                "uint", value,
                "hresult"
            )
            if hr != 0
                Direct2D.ThrowHResult("Set" . optionName, hr)
        }
    }

    CreateTextFormat(fontName, fontSize, fontWeight := 400, fontStyle := 0, options := 0) {
        return this.IDWriteFactory.CreateTextFormat(fontName, fontSize, fontWeight, fontStyle, options)
    }

    CreateTextLayout(text, pTextFormat, maxWidth := A_ScreenWidth, maxHeight := A_ScreenHeight, options := 0) {
        return this.IDWriteFactory.CreateTextLayout(text, pTextFormat, maxWidth, maxHeight, options)
    }

    GetTextLayoutMetrics(pTextLayout) {
        return this.IDWriteFactory.GetTextLayoutMetrics(pTextLayout, this.textMetricPrps)
    }

    GetTextLayoutLineMetrics(pTextLayout) {
        return this.IDWriteFactory.GetTextLayoutLineMetrics(pTextLayout, this.textMetricPrps)
    }

    ; GetMetrics for the formatted text.
    ; https://learn.microsoft.com/windows/win32/api/dwrite/ns-dwrite-dwrite_text_metrics
    GetMetrics(text, fontName := "Segoe UI", fontSize := 16, fontWeight := 400, fontStyle := 0, options := 0) {
        local pTextFormat := this.GetSavedOrCreateTextFormat(
            fontName,
            fontSize,
            fontWeight,
            fontStyle,
            this.GetTextFormatOption(options, "text_alignment", 0),
            this.GetTextFormatOption(options, "paragraph_alignment", 0),
            this.GetTextFormatOption(options, "reading_direction", 0),
            this.GetTextFormatOption(options, "flow_direction", 0)
        )
        local pTextLayout := this.CreateTextLayout(text, pTextFormat, A_ScreenWidth, A_ScreenHeight, Map(
            "reading_direction", this.GetTextFormatOption(options, "reading_direction", 0),
            "flow_direction", this.GetTextFormatOption(options, "flow_direction", 0)
        ))
        try {
            local metrics := this.GetTextLayoutMetrics(pTextLayout)
            return { w: metrics.width, h: metrics.height }
        } finally {
            Direct2D.release(pTextLayout)
        }
    }

    class ID2D1GeometrySink {
        static pointPrps := Buffer(8, 0)

        static Init(d2d1Factory) {
            this.pPathGeometry := d2d1Factory.CreatePathGeometry()
            DllCall(VT_Open := Direct2D.vTable(this.pPathGeometry, 17), "Ptr", this.pPathGeometry, "Ptr*", &pGeometrySink := 0)
            this.pGeometrySink := pGeometrySink
            if !pGeometrySink {
                MsgBox("ID2D1GeometrySink init failed")
                return
            }

            ; this.VT_SetFillMode := Direct2D.vTable(pGeometrySink, 3)
            ; D2D1_FILL_MODE_ALTERNATE = 0, D2D1_FILL_MODE_WINDING = 1,
            ; DllCall(this.VT_SetFillMode, "Ptr", pGeometrySink, "uint", 1)
            this.VT_BeginFigure := Direct2D.vTable(pGeometrySink, 5)
            ; this.VT_AddLines := Direct2D.vTable(pGeometrySink, 6)
            ; this.VT_AddBeziers := Direct2D.vTable(pGeometrySink, 7)
            this.VT_EndFigure := Direct2D.vTable(pGeometrySink, 8)
            this.VT_Close := Direct2D.vTable(pGeometrySink, 9)
            this.VT_AddLine := Direct2D.vTable(pGeometrySink, 10)
            this.VT_AddBezier := Direct2D.vTable(pGeometrySink, 11)
            ; this.VT_AddQuadraticBezier := Direct2D.vTable(pGeometrySink, 12)
            ; this.VT_AddQuadraticBeziers := Direct2D.vTable(pGeometrySink, 13)
            this.VT_AddArc := Direct2D.vTable(pGeometrySink, 14)

            return this
        }

        static BeginFigure(pointStart, figureBegin) {
            if Direct2D.isX64 {
                NumPut("float", pointStart[1], this.pointPrps, 0)
                NumPut("float", pointStart[2], this.pointPrps, 4)
                DllCall(this.VT_BeginFigure, "Ptr", this.pGeometrySink, "Double", NumGet(this.pointPrps, 0, "double"), "uint", figureBegin)
            } else {
                DllCall(this.VT_BeginFigure, "Ptr", this.pGeometrySink, "float", pointStart[1], "float", pointStart[2], "uint", figureBegin)
            }
        }

        static EndFigure(figureEnd) => DllCall(this.VT_EndFigure, "Ptr", this.pGeometrySink, "uint", figureEnd)

        static Close() => DllCall(this.VT_Close, "Ptr", this.pGeometrySink, "uint")

        static AddLine(linePoint) {
            if Direct2D.isX64 {
                NumPut("float", linePoint[1], this.pointPrps, 0)
                NumPut("float", linePoint[2], this.pointPrps, 4)
                DllCall(this.VT_AddLine, "Ptr", this.pGeometrySink, "Double", NumGet(this.pointPrps, 0, "double"))
            } else {
                DllCall(this.VT_AddLine, "Ptr", this.pGeometrySink, "float", linePoint[1], "float", linePoint[2])
            }
        }

        static AddBezier(bezier) => DllCall(this.VT_AddBezier, "Ptr", this.pGeometrySink, "Ptr", bezier)

        static AddArc(arc) => DllCall(this.VT_AddArc, "Ptr", this.pGeometrySink, "Ptr", arc)
    }

    class ID2D1RenderTarget {
        __New(target, width, height, d2d1Factory) {
            this.pRT := 0
            this.width := width, this.height := height
            this.drawInfoPrps := Buffer(16, 0)

            ; set window visible
            DllCall("SetLayeredWindowAttributes", "Uptr", target, "Uint", ColorKey := 0, "char", Alpha := 255, "uint", LWA_ALPHA := 2)

            static marginPrps := Buffer(16, 0)
            NumPut("int", -1, marginPrps, 0), NumPut("int", -1, marginPrps, 4)
            NumPut("int", -1, marginPrps, 8), NumPut("int", -1, marginPrps, 12)
            DllCall("dwmapi\DwmExtendFrameIntoClientArea", "Uptr", target, "ptr", marginPrps, "uint")

            static renderTargetPrps := Buffer(64, 0)
            NumPut("uint", 1, renderTargetPrps, 8) ; AlphaMode = D2D1_ALPHA_MODE_PREMULTIPLIED
            NumPut("float", 96, renderTargetPrps, 12) ; dpiX
            NumPut("float", 96, renderTargetPrps, 16) ; dpiY
            static hwndRenderTargetPrps := Buffer(64, 0)
            NumPut("Uptr", target, hwndRenderTargetPrps, 0)
            NumPut("uint", width, hwndRenderTargetPrps, A_PtrSize)
            NumPut("uint", height, hwndRenderTargetPrps, A_PtrSize + 4)
            NumPut("uint", 2, hwndRenderTargetPrps, A_PtrSize + 8)
            this.pRT := d2d1Factory.CreateHwndRenderTarget(renderTargetPrps, hwndRenderTargetPrps)
            if !this.pRT {
                MsgBox("ID2D1RenderTarget init failed")
                return 0
            }
            this.__InitCommonVT()

            ; ID2D1HwndRenderTarget
            this.VT_CheckWindowState := Direct2D.vTable(this.pRT, 57)
            this.VT_Resize := Direct2D.vTable(this.pRT, 58)
            this.VT_GetHwnd := Direct2D.vTable(this.pRT, 59)

            return this.pRT
        }

        __Delete() {
            if HasProp(this, "pRT") && this.pRT
                Direct2D.release(this.pRT), this.pRT := 0
        }

        __InitCommonVT() {
            ; ID2D1RenderTarget
            this.VT_CreateBitmap := Direct2D.vTable(this.pRT, 4)
            this.VT_CreateBitmapFromWicBitmap := Direct2D.vTable(this.pRT, 5)
            this.VT_CreateSharedBitmap := Direct2D.vTable(this.pRT, 6)
            this.VT_CreateBitmapBrush := Direct2D.vTable(this.pRT, 7)
            this.VT_CreateSolidBrush := Direct2D.vTable(this.pRT, 8)
            this.VT_CreateGradientStopCollection := Direct2D.vTable(this.pRT, 9)
            this.VT_CreateLinearGradientBrush := Direct2D.vTable(this.pRT, 10)
            this.VT_CreateRadialGradientBrush := Direct2D.vTable(this.pRT, 11)
            this.VT_CreateCompatibleRenderTarget := Direct2D.vTable(this.pRT, 12)
            this.VT_DrawLine := Direct2D.vTable(this.pRT, 15)
            this.VT_DrawRectangle := Direct2D.vTable(this.pRT, 16)
            this.VT_FillRectangle := Direct2D.vTable(this.pRT, 17)
            this.VT_DrawRoundedRectangle := Direct2D.vTable(this.pRT, 18)
            this.VT_FillRoundedRectangle := Direct2D.vTable(this.pRT, 19)
            this.VT_DrawEllipse := Direct2D.vTable(this.pRT, 20)
            this.VT_FillEllipse := Direct2D.vTable(this.pRT, 21)
            this.VT_DrawGeometry := Direct2D.vTable(this.pRT, 22)
            this.VT_FillGeometry := Direct2D.vTable(this.pRT, 23)
            this.VT_DrawBitmap := Direct2D.vTable(this.pRT, 26)
            this.VT_DrawText := Direct2D.vTable(this.pRT, 27)
            this.VT_DrawTextLayout := Direct2D.vTable(this.pRT, 28)
            this.VT_SetTransform := Direct2D.vTable(this.pRT, 30)
            this.VT_SetAntialiasMode := Direct2D.vTable(this.pRT, 32)
            this.VT_SetTextAntialiasMode := Direct2D.vTable(this.pRT, 34)
            this.VT_PushAxisAlignedClip := Direct2D.vTable(this.pRT, 45)
            this.VT_PopAxisAlignedClip := Direct2D.vTable(this.pRT, 46)
            this.VT_Clear := Direct2D.vTable(this.pRT, 47)
            this.VT_BeginDraw := Direct2D.vTable(this.pRT, 48)
            this.VT_EndDraw := Direct2D.vTable(this.pRT, 49)
        }

        CreateBitmap(w, h, srcData, pitch, bmpProps) {
            pBitmap := 0
            if Direct2D.isX64 {
                NumPut("uint", w, this.drawInfoPrps, 0)
                NumPut("uint", h, this.drawInfoPrps, 4)
                DllCall(this.VT_CreateBitmap, "Ptr", this.pRT, "int64", NumGet(this.drawInfoPrps, 0, "int64"), "Ptr", srcData, "uint", pitch, "Ptr", bmpProps, "Ptr*", &pBitmap)
            } else {
                DllCall(this.VT_CreateBitmap, "Ptr", this.pRT, "uint", w, "uint", h, "Ptr", srcData, "uint", pitch, "Ptr", bmpProps, "Ptr*", &pBitmap)
            }
            return pBitmap
        }

        CreateBitmapFromWicBitmap(pWicBitmapSource, bmpProps) =>
            (DllCall(this.VT_CreateBitmapFromWicBitmap, "Ptr", this.pRT, "Ptr", pWicBitmapSource, "Ptr", bmpProps, "Ptr*", &pBitmap := 0), pBitmap)

        CreateSharedBitmap(riid, pData, bitmapProps := 0) =>
            (DllCall(this.VT_CreateSharedBitmap, "Ptr", this.pRT, "Ptr", riid, "Ptr", pData, "Ptr", bitmapProps, "Ptr*", &pBitmap := 0), pBitmap)

        CreateBitmapBrush(pBitmap, bitmapProps := 0, brushProps := 0) =>
            (DllCall(this.VT_CreateBitmapBrush, "Ptr", this.pRT, "Ptr", pBitmap, "Ptr", bitmapProps, "Ptr", brushProps, "Ptr*", &pBitmapBrush := 0), pBitmapBrush)

        CreateSolidBrush(sColor, brushProps := 0) =>
            (DllCall(this.VT_CreateSolidBrush, "Ptr", this.pRT, "Ptr", sColor, "Ptr", brushProps, "Ptr*", &pBrush := 0), pBrush)

        CreateGradientStopCollection(gdColors) {
            count := gdColors.Count
            stride := 20
            gdStops := Buffer(count * stride, 0)

            i := 0
            for pos, color in gdColors {
                offset := i * stride
                NumPut("float", pos, gdStops, offset + 0)
                NumPut("Float", ((color & 0xFF0000) >> 16) / 255, gdStops, offset + 4)
                NumPut("Float", ((color & 0xFF00) >> 8) / 255, gdStops, offset + 8)
                NumPut("Float", ((color & 0xFF)) / 255, gdStops, offset + 12)
                NumPut("Float", (color > 0xFFFFFF ? ((color & 0xFF000000) >> 24) / 255 : 1), gdStops, offset + 16)
                i++
            }

            DllCall(this.VT_CreateGradientStopCollection, "Ptr", this.pRT, "Ptr", gdStops, "Uint", count, "Uint", gamma := 0, "Uint", extendModeClamp := 0, "Ptr*", &pGdStopCollection := 0)

            return pGdStopCollection
        }

        CreateLinearGradientBrush(linearGdProps, gdStopCollection, brushProps := 0) =>
            (DllCall(this.VT_CreateLinearGradientBrush, "Ptr", this.pRT, "Ptr", linearGdProps, "Ptr", brushProps, "Ptr", gdStopCollection, "Ptr*", &pLinearGdBrush := 0), pLinearGdBrush)

        CreateRadialGradientBrush(radialGdProps, gdStopCollection, brushProps := 0) =>
            (DllCall(this.VT_CreateRadialGradientBrush, "Ptr", this.pRT, "Ptr", radialGdProps, "Ptr", brushProps, "Ptr", gdStopCollection, "Ptr*", &pRadialGdBrush := 0), pRadialGdBrush)

        CreateCompatibleRenderTarget(desiredSize, desiredPixelSize, desiredFormat, opt) =>
            (DllCall(this.VT_CreateCompatibleRenderTarget, "Ptr", this.pRT, "Ptr", desiredSize, "Ptr", desiredPixelSize, "Ptr", desiredFormat, "Ptr", opt, "Ptr*", &pBitmapRenderTarget := 0), pBitmapRenderTarget)

        ; D2D1_POINT_2F is different in 32 and 64 bits
        ; reference https://github.com/Spawnova/ShinsOverlayClass/blob/main/AHK%20V2/ShinsOverlayClass.ahk#L626
        DrawLine(pointStart, pointEnd, pBrush, strokeWidth, pStrokeStyle) {
            if Direct2D.isX64 {
                NumPut("float", pointStart[1], this.drawInfoPrps, 0)
                NumPut("float", pointStart[2], this.drawInfoPrps, 4)
                NumPut("float", pointEnd[1], this.drawInfoPrps, 8)
                NumPut("float", pointEnd[2], this.drawInfoPrps, 12)
                DllCall(this.VT_DrawLine, "Ptr", this.pRT, "Double", NumGet(this.drawInfoPrps, 0, "double"), "Double", NumGet(this.drawInfoPrps, 8, "double"), "ptr", pBrush, "float", strokeWidth, "ptr", pStrokeStyle)
            } else {
                DllCall(this.VT_DrawLine, "Ptr", this.pRT, "float", pointStart[1], "float", pointStart[2], "float", pointEnd[1], "float", pointEnd[2], "ptr", pBrush, "float", strokeWidth, "ptr", pStrokeStyle)
            }
        }

        DrawRectangle(rect, pBrush, strokeWidth, pStrokeStyle) =>
            DllCall(this.VT_DrawRectangle, "Ptr", this.pRT, "Ptr", rect, "ptr", pBrush, "float", strokeWidth, "ptr", pStrokeStyle)

        FillRectangle(rect, pBrush) =>
            DllCall(this.VT_FillRectangle, "Ptr", this.pRT, "Ptr", rect, "ptr", pBrush)

        DrawRoundedRectangle(roundedRect, pBrush, strokeWidth, pStrokeStyle) =>
            DllCall(this.VT_DrawRoundedRectangle, "Ptr", this.pRT, "Ptr", roundedRect, "ptr", pBrush, "float", strokeWidth, "ptr", pStrokeStyle)

        FillRoundedRectangle(roundedRect, pBrush) =>
            DllCall(this.VT_FillRoundedRectangle, "Ptr", this.pRT, "Ptr", roundedRect, "ptr", pBrush)

        DrawEllipse(sEllipse, pBrush, strokeWidth, pStrokeStyle) =>
            DllCall(this.VT_DrawEllipse, "Ptr", this.pRT, "Ptr", sEllipse, "ptr", pBrush, "float", strokeWidth, "ptr", pStrokeStyle)

        FillEllipse(sEllipse, pBrush) =>
            DllCall(this.VT_FillEllipse, "Ptr", this.pRT, "Ptr", sEllipse, "ptr", pBrush)

        DrawGeometry(pGeometry, pBrush, strokeWidth, pStrokeStyle) =>
            DllCall(this.VT_DrawGeometry, "Ptr", this.pRT, "Ptr", pGeometry, "Ptr", pBrush, "float", strokeWidth, "ptr", pStrokeStyle)

        FillGeometry(pGeometry, pBrush, pOpacityBrush := 0) =>
            DllCall(this.VT_FillGeometry, "Ptr", this.pRT, "Ptr", pGeometry, "Ptr", pBrush, "Ptr", pOpacityBrush)

        DrawBitmap(pBitmap, destRect := 0, opacity := 1, interpolationMode := 1, srcRect := 0) =>
            DllCall(this.VT_DrawBitmap, "ptr", this.pRT,
                "ptr", pBitmap,
                "ptr", destRect,
                "float", opacity,
                "uint", interpolationMode,
                "ptr", srcRect)

        DrawText(text, pTextFormat, rect, pBrush, drawOpt) =>
            DllCall(this.VT_DrawText, "ptr", this.pRT, "wstr", text, "uint", strlen(text), "ptr", pTextFormat, "ptr", rect, "ptr", pBrush, "uint", drawOpt, "uint", 0)

        DrawTextLayout(point, pTextLayout, pBrush, drawOpt) {
            if Direct2D.isX64 {
                static pointPrps := Buffer(8, 0)
                NumPut('float', point[1], pointPrps, 0)
                NumPut('float', point[2], pointPrps, 4)
                DllCall(this.VT_DrawTextLayout, "ptr", this.pRT, 'double', NumGet(pointPrps, 0, 'double'), "ptr", pTextLayout, 'ptr', pBrush, "uint", drawOpt)
            } else {
                DllCall(this.VT_DrawTextLayout, "ptr", this.pRT, "float", point[1], "float", point[2], "ptr", pTextLayout, 'ptr', pBrush, "uint", drawOpt)
            }
        }

        SetTransform(pMatrix) => DllCall(this.VT_SetTransform, "Ptr", this.pRT, "Ptr", pMatrix)

        SetAntialiasMode(mode) => DllCall(this.VT_SetAntialiasMode, "Ptr", this.pRT, "Uint", mode)

        SetTextAntialiasMode(mode) => DllCall(this.VT_SetTextAntialiasMode, "Ptr", this.pRT, "Uint", mode)

        Clear() => DllCall(this.VT_Clear, "Ptr", this.pRT, "Ptr", 0)

        BeginDraw() => DllCall(this.VT_BeginDraw, "Ptr", this.pRT)

        EndDraw(&tag1 := 0, &tag2 := 0) =>
            DllCall(this.VT_EndDraw, "Ptr", this.pRT, "UInt64*", &tag1, "UInt64*", &tag2, "hresult")

        PushAxisAlignedClip(rect, antialiasMode := 0) =>
            DllCall(this.VT_PushAxisAlignedClip, "Ptr", this.pRT, "Ptr", rect, "UInt", antialiasMode)

        PopAxisAlignedClip() => DllCall(this.VT_PopAxisAlignedClip, "Ptr", this.pRT)

        Resize(size) => DllCall(this.VT_Resize, "Ptr", this.pRT, "ptr", size)
    }

    class ID2D1WicBitmapRenderTarget extends Direct2D.ID2D1RenderTarget {
        __New(imgW, imgH, d2d1Factory?) {
            this.width := imgW, this.height := imgH

            ; Initialize Windows Imaging Component.
            static CLSID_WICImagingFactory := "{CACAF262-9370-4615-A13B-9F5539DA4C0A}"
            static IID_IWICImagingFactory := "{EC5EC8A9-C395-4314-9C77-54D7A935FF70}"
            pWICImagingFactory := ComObject(CLSID_WICImagingFactory, IID_IWICImagingFactory)
            ; WicBitmapRenderTarget must be pixelFormat32bppPBGRA
            this.pixelFormatCLSID := IsSet(d2d1Factory) ? Direct2D.guid["GUID_WICPixelFormat32bppPBGRA"] : Direct2D.guid["GUID_WICPixelFormat32bppBGRA"]
            ComCall(CreateBitmap := 17, pWICImagingFactory, ; IWICImagingFactory::CreateBitmap in memory
                "uint", this.width, "uint", this.height,
                "ptr", this.pixelFormatCLSID,
                "uint", WICBitmapCacheOnDemand := 1,
                "ptr*", &pWICBitmap := 0)
            this.pWICBitmap := pWICBitmap

            if !IsSet(d2d1Factory) ; to use WicBitmap mode
                return 0

            static renderTargetPrps := Buffer(64, 0)
            NumPut("uint", 1, renderTargetPrps, 0) ; D2D1_RENDER_TARGET_TYPE_SOFTWARE
            NumPut("uint", 87, renderTargetPrps, 4) ; DXGI_FORMAT_B8G8R8A8_UNORM
            NumPut("uint", 1, renderTargetPrps, 8) ; AlphaMode = D2D1_ALPHA_MODE_PREMULTIPLIED
            if !this.pRT := d2d1Factory.CreateWicBitmapRenderTarget(pWicBitmap, renderTargetPrps) {
                MsgBox("ID2D1WicBitmapRenderTarget init failed")
                return 0
            }

            super.__InitCommonVT()
            this.VT_CreateEffect := Direct2D.vTable(this.pRT, 63)
            this.VT_DrawImage := Direct2D.vTable(this.pRT, 83)
            this.VT_CreateSvgDocument := Direct2D.vTable(this.pRT, 115)
            this.VT_DrawSvgDocument := Direct2D.vTable(this.pRT, 116)

            return this.pRT
        }

        __Delete() {
            super.__Delete()

            if this.pWICBitmap
                Direct2D.release(this.pWICBitmap), this.pWICBitmap := 0
        }

        GetWICBitmap() => this.pWICBitmap

        WICBitmapToWICBitmapSource() => (DllCall("windowscodecs\WICConvertBitmapSource", "ptr", this.pixelFormatCLSID, "ptr", this.pWICBitmap, "ptr*", &pWICBitmapSource := 0), pWICBitmapSource)

        CreateEffect(effectClsid) => (DllCall(this.VT_CreateEffect, "Ptr", this.pRT, "Ptr", effectClsid, "Ptr*", &pID2D1Effect := 0), pID2D1Effect)

        DrawImage(pD2dBitmap, targetOffset := 0, imageRect := 0, interpolationMode := 1, compositeMode := 0) =>
            DllCall(this.VT_DrawImage, "Ptr", this.pRT, "Ptr", pD2dBitmap, "Ptr", targetOffset, "Ptr", imageRect, "Ptr", interpolationMode, "Ptr", compositeMode)

        CreateSvgDocument(fs, w, h) {
            local pSvgDocument := 0
            if Direct2D.isX64 {
                static sizePrps := Buffer(8, 0)
                NumPut("float", w, sizePrps, 0)
                NumPut("float", h, sizePrps, 4)
                DllCall(this.VT_CreateSvgDocument, "Ptr", this.pRT, "ptr", fs, "uint64", NumGet(sizePrps, "uint64"), "ptr*", &pSvgDocument)
            } else {
                DllCall(this.VT_CreateSvgDocument, "Ptr", this.pRT, "ptr", fs, "float", w, "float", h, "ptr*", &pSvgDocument)
            }
            return pSvgDocument
        }

        DrawEffectImage(pGdiBitmap, effectClsid, effectProps) {
            pWICBitmapSource := this.GdiBitmapToWICBitmapSource(pGdiBitmap, Format32bppPArgb := 0xE200B)
            static d2dBmpPrps := Buffer(64, 0)
            NumPut("uint", 87, d2dBmpPrps, 0) ; DXGI_FORMAT_B8G8R8A8_UNORM
            NumPut("uint", 1, d2dBmpPrps, 4)  ; D2D1_ALPHA_MODE_PREMULTIPLIED
            pD2dBitmap := this.CreateBitmapFromWicBitmap(this.pWICBitmap, d2dBmpPrps)

            pEffect := this.CreateEffect(effectClsid)
            DllCall(Direct2D.vTable(pEffect, 14), ; SetInput
                "Ptr", pEffect, "Uint", 0, "Ptr", pD2dBitmap, "Int", invalidate := 1)
            for i, v in effectProps
                DllCall(Direct2D.vTable(pEffect, 9), "Ptr", pEffect, ; SetValue
                    "Uint", v.idx, "Int", v.type, v.byte, v.data, "Uint", v.dataSize)
            DllCall(Direct2D.vTable(pEffect, 18), "Ptr", pEffect, ; GetOutput
                "Ptr*", &pOutD2dBitmap := 0)

            this.BeginDraw()
            this.Clear()
            this.DrawImage(pOutD2dBitmap)
            this.EndDraw()

            Direct2D.release(pOutD2dBitmap)
            return this.WICBitmapToWICBitmapSource()
        }

        DrawSvgDocument(pSvgDocument) => DllCall(this.VT_DrawSvgDocument, "Ptr", this.pRT, "Ptr", pSvgDocument)

        DrawSvgWICBitmap(fs) {
            local p_svg_document := 0

            try {
                p_svg_document := this.CreateSvgDocument(fs, this.width, this.height) ; ID2D1SvgDocument
                if !p_svg_document
                    throw Error("Failed to create the SVG document.")

                this.BeginDraw()
                this.DrawSvgDocument(p_svg_document)
                this.EndDraw()
            } finally {
                if p_svg_document
                    Direct2D.release(p_svg_document)
                if fs
                    ObjRelease(fs)
            }
        }

        GetSvgHBitmap(fs) {
            this.DrawSvgWICBitmap(fs)
            return this.GetHBitmapFromWICBitmap()
        }

        GetSvgWICBitmapSource(fs) {
            this.DrawSvgWICBitmap(fs)
            return this.WICBitmapToWICBitmapSource()
        }

        GetHBitmapFromWICBitmap() {
            stride := 4 * this.width
            pData := Buffer(stride * this.height)
            ComCall(CopyPixels := 7, this.pWICBitmap, "ptr", 0, "uint", stride, "uint", pData.Size, "ptr", pData)
            hBitmap := DllCall("gdi32\CreateBitmap", "Int", this.width, "Int", this.height, "Uint", 1, "Uint", 32, "Ptr", pData, "Ptr")

            Direct2D.release(this.pWICBitmap), this.pWICBitmap := 0
            return hBitmap
        }

        GdiBitmapToWICBitmapSource(pGdiBitmap, gdiPixelFormat) {
            local gdi_bitmap_locked := false, p_wic_bitmap_lock := 0

            if !pGdiBitmap
                return 0

            ; convert GdiBitmap to WICBitmap
            static sRect := Buffer(16, 0)
            NumPut("uint", this.width, sRect, 8)
            NumPut("uint", this.height, sRect, 12)
            try {
                ComCall(Lock := 8, this.pWICBitmap, "ptr", sRect, "uint", 0x2, "ptr*", &p_wic_bitmap_lock)
                ComCall(GetDataPointer := 5, p_wic_bitmap_lock, "uint*", &size := 0,
                    "ptr*", &p_wic_bitmap_data := 0)
                ; copy GdiBitmap data to WICBitmap data
                static pBitmapData := Buffer(16 + 2 * A_PtrSize, 0)
                NumPut("int", 4 * this.width, pBitmapData, 8) ; stride
                NumPut("ptr", p_wic_bitmap_data, pBitmapData, 16) ; scan0
                status := DllCall("gdiplus\GdipBitmapLockBits", "ptr", pGdiBitmap, "ptr", sRect,
                    "uint", 5, ; UserInputBuffer | ReadOnly
                    "int", gdiPixelFormat, ; Format32bppPArgb:0xE200B
                    "ptr", pBitmapData)
                if status
                    throw Error(Format("GdipBitmapLockBits failed (status {}).", status))
                gdi_bitmap_locked := true

                return this.WICBitmapToWICBitmapSource()
            } finally {
                if gdi_bitmap_locked
                    DllCall("gdiplus\GdipBitmapUnlockBits", "ptr", pGdiBitmap, "ptr", pBitmapData)
                if p_wic_bitmap_lock
                    ObjRelease(p_wic_bitmap_lock)
            }
        }
    }

    class ID2D1DCRenderTarget extends Direct2D.ID2D1RenderTarget {
        __New(d2d1Factory) {
            static renderTargetPrps := Buffer(64, 0)
            NumPut("uint", 87, renderTargetPrps, 4) ; DXGI_FORMAT_B8G8R8A8_UNORM
            NumPut("uint", 1, renderTargetPrps, 8) ; AlphaMode = D2D1_ALPHA_MODE_PREMULTIPLIED
            this.pRT := d2d1Factory.CreateDCRenderTarget(renderTargetPrps)
            if !this.pRT {
                MsgBox("ID2D1DCRenderTarget init failed")
                return 0
            }

            super.__InitCommonVT()
            this.VT_BindDC := Direct2D.vTable(this.pRT, 57)

            return this.pRT
        }

        BindDC(hDC, rect) => DllCall(this.VT_BindDC, "Ptr", this.pRT, "ptr", hDC, "ptr", rect)
    }

    /**
     * @param {Integer | String} target GuiObj or GuiHwnd for hwndTraget, "wic" for WicBitmapTarget
     * @param {Integer} w GuiClient or WicBitmap width
     * @param {Integer} h GuiClient or WicBitmap height
     * @returns {Direct2D.ID2D1RenderTarget | Direct2D.ID2D1WicBitmapRenderTarget}
     */
    SetRenderTarget(target, w := 0, h := 0) {
        local target_hwnd := 0

        if target && IsInteger(target)
            target_hwnd := target
        else if target is Gui
            target_hwnd := target.Hwnd
        if !target_hwnd || target_hwnd != this.erase_background_hwnd
            this.UnregisterEraseBackgroundHandler()

        this.target := target, this.hwnd := 0, this.attachHwnd := 0
        this.x := 0, this.y := 0, this.width := w, this.height := h
        this.clipDepth := 0
        this.winRect := []
        if target && IsInteger(target) {
            this.hwnd := target
            this.ID2D1RenderTarget := Direct2D.ID2D1RenderTarget(this.hwnd, this.width, this.height, this.ID2D1Factory)
        } else if target is String {
            if target = "wic" {
                if w == 0 || h == 0 {
                    MsgBox("WicBitmapRenderTarget needs width and height for a image!")
                    return 0
                }
                this.ID2D1RenderTarget := Direct2D.ID2D1WicBitmapRenderTarget(this.width, this.height, this.ID2D1Factory)
            } else if target = "dc" { ; gdip DC
                this.ID2D1RenderTarget := Direct2D.ID2D1DCRenderTarget(this.ID2D1Factory)
            } else { ; attach to a window
                this.lastSize := 0, this.lastPos := 0
                if this.attachHwnd := WinExist(target) {
                    this.gui := Gui("-DPIScale -Caption +E0x80800A8")
                    this.hwnd := this.gui.Hwnd
                    this.ID2D1RenderTarget := Direct2D.ID2D1RenderTarget(this.hwnd, this.width, this.height, this.ID2D1Factory)
                } else {
                    MsgBox(Format('WinTitle "{}" is not exists', target))
                    return 0
                }
            }
        } else if target is Gui {
            this.hwnd := target.Hwnd
            this.ID2D1RenderTarget := Direct2D.ID2D1RenderTarget(this.hwnd, this.width, this.height, this.ID2D1Factory)
        } else {
            MsgBox("Unsupported target!")
            return 0
        }

        if this.hwnd && !this.erase_background_callback {
            this.erase_background_hwnd := this.hwnd
            this.erase_background_callback := ObjBindMethod(
                Direct2D, "SuppressEraseBackground", this.erase_background_hwnd)
            OnMessage(WM_ERASEBKGND := 0x14, this.erase_background_callback)
        }

        this.ID2D1RenderTarget.SetAntiAliasMode(D2D1_ANTIALIAS_MODE_PER_PRIMITIVE := 0)
        this.ID2D1RenderTarget.SetTextAntiAliasMode(D2D1_TEXT_ANTIALIAS_MODE_CLEARTYPE := 1)
        this.Clear()

        return this.ID2D1RenderTarget
    }

    UnregisterEraseBackgroundHandler() {
        if this.erase_background_callback {
            OnMessage(WM_ERASEBKGND := 0x14, this.erase_background_callback, 0)
            this.erase_background_callback := 0
            this.erase_background_hwnd := 0
        }
    }

    UpdatePosition() {
        if this.attachHwnd {
            hasWinRect := DllCall("GetWindowInfo", "Uptr", this.attachHWND, "ptr", this.winInfoPrps)
            onActiveWin := DllCall("GetForegroundWindow", "cdecl Ptr") == this.attachHwnd
            if !hasWinRect or !onActiveWin {
                return attachFailed()
            } else if (!this.isDrawing) {
                DllCall("ShowWindow", "Ptr", this.hwnd, "Int", 4)
            }
        } else {
            if !DllCall("GetWindowInfo", "Uptr", this.hwnd, "ptr", this.winInfoPrps) {
                return attachFailed()
            }
        }
        x := NumGet(this.winInfoPrps, 4, "int"), y := NumGet(this.winInfoPrps, 8, "int")
        right := NumGet(this.winInfoPrps, 12, "int"), bottom := NumGet(this.winInfoPrps, 16, "int")
        w := right - x, h := bottom - y
        this.winRect := [x, y, right, bottom]
        cxWindowBorders := NumGet(this.winInfoPrps, 48, "int"), cyWindowBorders := NumGet(this.winInfoPrps, 52, "int")
        sizeCode := (w << 16) + h, posCode := (x << 16) + y
        if (sizeCode != this.lastSize) {
            this.SetPosition(x + cyWindowBorders, y, w - cyWindowBorders * 2, h - cxWindowBorders)
            this.lastSize := sizeCode, this.lastPos := posCode
        } else if (posCode != this.lastPos) {
            this.SetPosition(x + cyWindowBorders, y)
            this.lastPos := posCode
        }
        return 1

        attachFailed() {
            if (this.isDrawing) {
                this.Clear()
                this.isDrawing := 0
                DllCall("ShowWindow", "Ptr", this.hwnd, "Int", 0)
            }
            return 0
        }
    }

    SetBrushProps(pBrush, pTransMatrix, opacity?) {
        if pTransMatrix
            DllCall(Direct2D.vTable(pBrush, 5), "Ptr", pBrush, "Ptr", pTransMatrix)
        if IsSet(opacity) && opacity > 0
            DllCall(Direct2D.vTable(pBrush, 4), "Ptr", pBrush, "float", opacity)
    }

    SetSolidBrushColor(pSdBrush, color) {
        if IsInteger(color) {
            NumPut("Float", ((color & 0xFF0000) >> 16) / 255, this.colorPrps, 0)  ; R
            NumPut("Float", ((color & 0xFF00) >> 8) / 255, this.colorPrps, 4)  ; G
            NumPut("Float", ((color & 0xFF)) / 255, this.colorPrps, 8)  ; B
            NumPut("Float", (color > 0xFFFFFF ? ((color & 0xFF000000) >> 24) / 255 : 1), this.colorPrps, 12) ; A
            DllCall(Direct2D.vTable(pSdBrush, 8), "Ptr", pSdBrush, "Ptr", this.colorPrps)
        }
    }

    SetLinearGdBurshProps(pGdBrush, pTransMatrix, startPoint, endPoint, opacity?) {
        if pTransMatrix
            DllCall(Direct2D.vTable(pGdBrush, 5), "Ptr", pGdBrush, "Ptr", pTransMatrix)
        if Direct2D.isX64 {
            NumPut("Float", startPoint[1], this.pointPrps, 0)
            NumPut("Float", startPoint[2], this.pointPrps, 4)
            NumPut("Float", endPoint[1], this.pointPrps, 8)
            NumPut("Float", endPoint[2], this.pointPrps, 12)
            DllCall(Direct2D.vTable(pGdBrush, 8), "Ptr", pGdBrush, "double", NumGet(this.pointPrps, 0, "double"))
            DllCall(Direct2D.vTable(pGdBrush, 9), "Ptr", pGdBrush, "double", NumGet(this.pointPrps, 8, "double"))
        } else {
            DllCall(Direct2D.vTable(pGdBrush, 8), "Ptr", pGdBrush, "float", startPoint[1], "float", startPoint[2])
            DllCall(Direct2D.vTable(pGdBrush, 9), "Ptr", pGdBrush, "float", endPoint[1], "float", endPoint[2])
        }

        if IsSet(opacity) && opacity > 0
            DllCall(Direct2D.vTable(pGdBrush, 4), "Ptr", pGdBrush, "float", opacity)
    }

    MakeRotateMatrix(angle, centerX, centerY) {
        static mat := Buffer(24)
        if (Direct2D.isX64) {
            NumPut("float", centerX, this.pointPrps, 0)
            NumPut("float", centerY, this.pointPrps, 4)
            DllCall("d2d1\D2D1MakeRotateMatrix", "float", angle, "double", NumGet(this.pointPrps, 0, "double"), "ptr", mat)
        } else {
            DllCall("d2d1\D2D1MakeRotateMatrix", "float", angle, "float", centerX, "float", centerY, "ptr", mat)
        }
        return mat ; D2D1_MATRIX_3X2_F
    }

    BeginDraw() {
        if this.attachHwnd {
            if !this.UpdatePosition()
                return 0
        }

        this.ID2D1RenderTarget.BeginDraw()
        this.ID2D1RenderTarget.Clear()
        return this.isDrawing := 1
    }

    EndDraw() {
        if !this.isDrawing
            return 0
        local clipDepth := this.clipDepth
        local tag1 := 0
        local tag2 := 0
        local hr
        try {
            hr := this.ID2D1RenderTarget.EndDraw(&tag1, &tag2)
        } finally {
            this.isDrawing := 0
            this.clipDepth := 0
        }
        if clipDepth
            throw Error(Format("EndDraw called with {} unclosed axis-aligned clip(s).", clipDepth))
        return hr
    }

    Clear() {
        this.ID2D1RenderTarget.BeginDraw()
        this.ID2D1RenderTarget.Clear()
        this.ID2D1RenderTarget.EndDraw()
    }

    ResizeRenderTarget(w, h) {
        if !HasProp(this.ID2D1RenderTarget, "VT_Resize") || !this.ID2D1RenderTarget.VT_Resize
            throw Error("The current render target does not support ResizeRenderTarget.")
        static D2D1_SIZE_U := Buffer(16, 0)
        NumPut("uint", w, D2D1_SIZE_U, 0)
        NumPut("uint", h, D2D1_SIZE_U, 4)
        local hr := this.ID2D1RenderTarget.Resize(D2D1_SIZE_U)
        if hr = 0
            this.width := w, this.height := h
        return hr
    }

    GetRenderTargetSize() {
        return { width: this.width, height: this.height }
    }

    PushAxisAlignedClip(x, y, w, h, antialiasMode := 0) {
        NumPut("float", x, this.drawBoundsPrps, 0)
        NumPut("float", y, this.drawBoundsPrps, 4)
        NumPut("float", x + w, this.drawBoundsPrps, 8)
        NumPut("float", y + h, this.drawBoundsPrps, 12)
        this.ID2D1RenderTarget.PushAxisAlignedClip(this.drawBoundsPrps, antialiasMode)
        return ++this.clipDepth
    }

    PopAxisAlignedClip() {
        if this.clipDepth <= 0
            throw Error("PopAxisAlignedClip called without a matching PushAxisAlignedClip.")
        this.ID2D1RenderTarget.PopAxisAlignedClip()
        return --this.clipDepth
    }

    CreateLinearGradientBrush(startX, startY, endX, endY, gdColors) {
        NumPut("float", startX, this.drawBoundsPrps, 0)
        NumPut("float", startY, this.drawBoundsPrps, 4)
        NumPut("float", endX, this.drawBoundsPrps, 8)
        NumPut("float", endY, this.drawBoundsPrps, 12)
        pGradientdStops := this.GetSavedOrCreateGradientdStops(gdColors)
        return this.ID2D1RenderTarget.CreateLinearGradientBrush(this.drawBoundsPrps, pGradientdStops)
    }

    CreateRadialGradientBrush(centerX, centerY, gdOriginOffsetX, gdOriginOffsetY, radiusX, radiusY, gdColors) {
        NumPut("float", centerX, this.drawBoundsPrps, 0)
        NumPut("float", centerY, this.drawBoundsPrps, 4)
        NumPut("float", gdOriginOffsetX, this.drawBoundsPrps, 8)
        NumPut("float", gdOriginOffsetY, this.drawBoundsPrps, 12)
        NumPut("float", radiusX, this.drawBoundsPrps, 16)
        NumPut("float", radiusY, this.drawBoundsPrps, 20)
        pGradientdStops := this.GetSavedOrCreateGradientdStops(gdColors)
        return this.ID2D1RenderTarget.CreateRadialGradientBrush(this.drawBoundsPrps, pGradientdStops)
    }

    /**
     * @param {String} text text to draw
     * @param {Integer} x text box left
     * @param {Integer} y text box top
     * @param {Integer} fontSize font size
     * @param {Integer} color font color(hex agbr)
     * @param {Integer} fontName font family
     * @param {Integer} w text box width, if not set it will use target width
     * @param {Integer} h text box Height, if not set it will use target height
     * @param {Object} fontOpt default { fontWeight: 400, fontStyle: 0, horizonAlign: 0, verticalAlign: 0 }
     *
     * fontWeight -> light 300, regular(normal): 400, medium:500, semiBold:600, bold: 700
     *
     * fontStyle -> normal: 0, oblique: 1 italic: 2
     *
     * horizonAlign -> DWRITE_TEXT_ALIGNMENT leading(left): 0, trailing(right): 1, center: 2, justified: 3
     *
     * verticalAlign -> DWRITE_PARAGRAPH_ALIGNMENT near(top): 0, far(bottom): 1,  middle(center): 2
     * @param {Boolean} drawShadow 0 is false
     * @param {Integer} drawOpt D2D1_DRAW_TEXT_OPTIONS
     */
    DrawText(text, x, y, fontSize, color, fontName, w?, h?, fontOpt?, drawShadow := 0, drawOpt := 4) {
        fontOpt ?? fontOpt := { fontWeight: 400, fontStyle: 0, horizonAlign: 0, verticalAlign: 0 }
        pTextFormat := this.GetSavedOrCreateTextFormat(
            fontName,
            fontSize,
            this.GetTextFormatOption(fontOpt, "fontWeight", 400),
            this.GetTextFormatOption(fontOpt, "fontStyle", 0),
            this.GetTextFormatOption(fontOpt, "horizonAlign", 0),
            this.GetTextFormatOption(fontOpt, "verticalAlign", 0),
            this.GetTextFormatOption(fontOpt, "readingDirection", 0),
            this.GetTextFormatOption(fontOpt, "flowDirection", 0)
        )
        pBrushText := this.GetSavedOrCreateSolidBrush(color)

        NumPut("float", x + (w ?? this.width), this.drawBoundsPrps, 8)
        NumPut("float", y + (h ?? this.height), this.drawBoundsPrps, 12)
        if (drawShadow) {
            NumPut("float", x + 5, this.drawBoundsPrps, 0)
            NumPut("float", y + 5, this.drawBoundsPrps, 4)
            pBrushShadow := this.GetSavedOrCreateSolidBrush(0x55000000)
            this.ID2D1RenderTarget.DrawText(text, pTextFormat, this.drawBoundsPrps, pBrushShadow, 0)
        }

        NumPut("float", x, this.drawBoundsPrps, 0)
        NumPut("float", y, this.drawBoundsPrps, 4)
        ; https://learn.microsoft.com/windows/win32/api/d2d1/ne-d2d1-d2d1_draw_text_options
        ; typedef enum D2D1_DRAW_TEXT_OPTIONS {
        ;   D2D1_DRAW_TEXT_OPTIONS_NO_SNAP = 0x00000001,
        ;   D2D1_DRAW_TEXT_OPTIONS_CLIP = 0x00000002,
        ;   D2D1_DRAW_TEXT_OPTIONS_ENABLE_COLOR_FONT = 0x00000004,
        ;   D2D1_DRAW_TEXT_OPTIONS_DISABLE_COLOR_BITMAP_SNAPPING = 0x00000008,
        ;   D2D1_DRAW_TEXT_OPTIONS_NONE = 0x00000000,
        ;   D2D1_DRAW_TEXT_OPTIONS_FORCE_DWORD = 0xffffffff
        ; }
        this.ID2D1RenderTarget.DrawText(text, pTextFormat, this.drawBoundsPrps, pBrushText, drawOpt)
    }

    DrawTextLayout(text, x, y, color, pTextLayout, drawOpt := 4) {
        if !text {
            Direct2D.release(pTextLayout)
            return
        }

        pBrush := this.GetSavedOrCreateSolidBrush(color)
        try {
            this.ID2D1RenderTarget.DrawTextLayout([x, y], pTextLayout, pBrush, drawOpt)
        } finally {
            Direct2D.release(pTextLayout)
        }
    }

    DrawTextWithLayout(text, x, y, fontSize, color, fontName, w?, h?, fontOpt?, drawOpt := 4) {
        if !text {
            return
        }
        fontOpt ?? fontOpt := { fontWeight: 400, fontStyle: 0, horizonAlign: 0, verticalAlign: 0 }
        local readingDirection := this.GetTextFormatOption(fontOpt, "readingDirection", 0)
        local flowDirection := this.GetTextFormatOption(fontOpt, "flowDirection", 0)
        local pTextFormat := this.GetSavedOrCreateTextFormat(
            fontName,
            fontSize,
            this.GetTextFormatOption(fontOpt, "fontWeight", 400),
            this.GetTextFormatOption(fontOpt, "fontStyle", 0),
            this.GetTextFormatOption(fontOpt, "horizonAlign", 0),
            this.GetTextFormatOption(fontOpt, "verticalAlign", 0),
            readingDirection,
            flowDirection
        )
        local pTextLayout := this.CreateTextLayout(
            text,
            pTextFormat,
            w ?? this.width,
            h ?? this.height,
            Map("reading_direction", readingDirection, "flow_direction", flowDirection)
        )
        this.DrawTextLayout(text, x, y, color, pTextLayout, drawOpt)
    }

    /**
     * @param {Array}  pointStart [x, y]
     * @param {Array} pointEnd [x, y]
     * @param {Integer} color abgr 0xFFFFFFFF
     * @param {Integer} strokeWidth thickness for stroke
     * @param {Integer} strokeCapStyle flat(0) square(1) round(2) triangle(3)
     * @param {Integer} strokeShapeStyle solid(0) dash(1) dot(2) dash_dot(3)
     */
    DrawLine(pointStart, pointEnd, color, strokeWidth := 2, strokeCapStyle := 2, strokeShapeStyle := 0) {
        pBrush := this.GetSavedOrCreateSolidBrush(color)
        pStrokeStyle := this.GetSavedOrCreateStrokeStyle(strokeCapStyle, strokeShapeStyle)
        this.ID2D1RenderTarget.DrawLine(pointStart, pointEnd, pBrush, strokeWidth, pStrokeStyle)
    }

    /**
     * @param {Array}  points [[x1, y1], [x2, y2], [x3, y3]]
     * @param {Integer} color abgr 0xFFFFFFFF
     * @param {Boolean} close connect the start point
     * @param {Integer} strokeWidth thickness for stroke
     * @param {Integer} strokeCapStyle flat(0) square(1) round(2) triangle(3)
     * @param {Integer} strokeShapeStyle solid(0) dash(1) dot(2) dash_dot(3)
     */
    DrawLines(points, color, close := 0, strokeWidth := 2, strokeCapStyle := 2, strokeShapeStyle := 0) {
        if (points.length < 2)
            return 0

        pBrush := this.GetSavedOrCreateSolidBrush(color)
        pStrokeStyle := this.GetSavedOrCreateStrokeStyle(strokeCapStyle, strokeShapeStyle)

        loop points.length - 1 {
            this.ID2D1RenderTarget.DrawLine(points[A_Index], points[A_Index + 1], pBrush, strokeWidth, pStrokeStyle)
        }

        if close
            this.ID2D1RenderTarget.DrawLine(points[points.length], points[1], pBrush, strokeWidth, pStrokeStyle)
    }

    DrawGeometry(points, color, strokeWidth := 2, strokeCapStyle := 2, strokeShapeStyle := 0) {
        if (points.length < 3)
            return 0

        pBrush := this.GetSavedOrCreateSolidBrush(color)
        pStrokeStyle := this.GetSavedOrCreateStrokeStyle(strokeCapStyle, strokeShapeStyle)
        GeometrySink := Direct2D.ID2D1GeometrySink.Init(this.ID2D1Factory)
        GeometrySink.BeginFigure(points[1], 1) ; D2D1_FIGURE_BEGIN_HOLLOW
        loop points.length - 1
            GeometrySink.AddLine(points[A_Index + 1])
        GeometrySink.EndFigure(1) ; D2D1_FIGURE_END_CLOSED
        GeometrySink.Close()

        this.ID2D1RenderTarget.DrawGeometry(GeometrySink.pPathGeometry, pBrush, strokeWidth, pStrokeStyle)
        Direct2D.release(GeometrySink.pGeometrySink)
        Direct2D.release(GeometrySink.pPathGeometry)
    }

    FillGeometry(points, color) {
        if (points.length < 3)
            return 0

        pBrush := this.GetSavedOrCreateSolidBrush(color)
        GeometrySink := Direct2D.ID2D1GeometrySink.Init(this.ID2D1Factory)
        GeometrySink.BeginFigure(points[1], 0) ; D2D1_FIGURE_BEGIN_FILLED
        loop points.length - 1
            GeometrySink.AddLine(points[A_Index + 1])
        GeometrySink.EndFigure(1) ; D2D1_FIGURE_END_CLOSED
        GeometrySink.Close()

        this.ID2D1RenderTarget.FillGeometry(GeometrySink.pPathGeometry, pBrush)
        Direct2D.release(GeometrySink.pGeometrySink)
        Direct2D.release(GeometrySink.pPathGeometry)
    }

    DrawRectangle(x, y, w, h, color, strokeWidth := 2, strokeCapStyle := 0, strokeShapeStyle := 0) {
        pBrush := this.GetSavedOrCreateSolidBrush(color)
        pStrokeStyle := this.GetSavedOrCreateStrokeStyle(strokeCapStyle, strokeShapeStyle)
        NumPut("float", x, this.drawBoundsPrps, 0)
        NumPut("float", y, this.drawBoundsPrps, 4)
        NumPut("float", x + w, this.drawBoundsPrps, 8)
        NumPut("float", y + h, this.drawBoundsPrps, 12)
        this.ID2D1RenderTarget.DrawRectangle(this.drawBoundsPrps, pBrush, strokeWidth, pStrokeStyle)
    }

    FillRectangle(x, y, w, h, color) {
        pBrush := this.GetSavedOrCreateSolidBrush(color)
        NumPut("float", x, this.drawBoundsPrps, 0)
        NumPut("float", y, this.drawBoundsPrps, 4)
        NumPut("float", x + w, this.drawBoundsPrps, 8)
        NumPut("float", y + h, this.drawBoundsPrps, 12)
        this.ID2D1RenderTarget.FillRectangle(this.drawBoundsPrps, pBrush)
    }

    /**
     * @param {Integer} x rectangle left
     * @param {Integer} y rectangle top
     * @param {Integer} w rectangle width
     * @param {Integer} h rectangle height
     * @param {Integer} connerRX rectangle conner x radial
     * @param {Integer} connerRY rectangle conner y radial
     * @param {Integer} pGdBrush this.CreateLinearGradientBrush(x, y, x + w, y, gdColors)
     * @example pBrush := this.CreateRadialGradientBrush((x + x + w) / 2, (y + y + h) / 2, 0, 0, w / 2, h / 2, gdColors)
     * this.FillGradientRoundedRect(x, y, w, h, connerRX, connerRY, pBrush)
     */
    FillGradientRectangle(x, y, w, h, connerRX, connerRY, pGdBrush) {
        NumPut("float", x, this.drawBoundsPrps, 0)
        NumPut("float", y, this.drawBoundsPrps, 4)
        NumPut("float", x + w, this.drawBoundsPrps, 8)
        NumPut("float", y + h, this.drawBoundsPrps, 12)
        this.ID2D1RenderTarget.FillRectangle(this.drawBoundsPrps, pGdBrush)
    }

    DrawRoundedRectangle(x, y, w, h, connerRX, connerRY, color, strokeWidth := 2, strokeCapStyle := 2, strokeShapeStyle := 0) {
        pBrush := this.GetSavedOrCreateSolidBrush(color)
        pStrokeStyle := this.GetSavedOrCreateStrokeStyle(strokeCapStyle, strokeShapeStyle)
        NumPut("float", x, this.drawBoundsPrps, 0)
        NumPut("float", y, this.drawBoundsPrps, 4)
        NumPut("float", x + w, this.drawBoundsPrps, 8)
        NumPut("float", y + h, this.drawBoundsPrps, 12)
        NumPut("float", connerRX, this.drawBoundsPrps, 16)
        NumPut("float", connerRY, this.drawBoundsPrps, 20)
        this.ID2D1RenderTarget.DrawRoundedRectangle(this.drawBoundsPrps, pBrush, strokeWidth, pStrokeStyle)
    }

    FillRoundedRectangle(x, y, w, h, connerRX, connerRY, color) {
        pBrush := this.GetSavedOrCreateSolidBrush(color)
        NumPut("float", x, this.drawBoundsPrps, 0)
        NumPut("float", y, this.drawBoundsPrps, 4)
        NumPut("float", x + w, this.drawBoundsPrps, 8)
        NumPut("float", y + h, this.drawBoundsPrps, 12)
        NumPut("float", connerRX, this.drawBoundsPrps, 16)
        NumPut("float", connerRY, this.drawBoundsPrps, 20)
        this.ID2D1RenderTarget.FillRoundedRectangle(this.drawBoundsPrps, pBrush)
    }

    /**
     * @param {Integer} x rectangle left
     * @param {Integer} y rectangle top
     * @param {Integer} w rectangle width
     * @param {Integer} h rectangle height
     * @param {Integer} connerRX rectangle conner x radial
     * @param {Integer} connerRY rectangle conner y radial
     * @param {Integer} pGdBrush this.CreateLinearGradientBrush(x, y, x + w, y, gdColors)
     * @example pBrush := this.CreateRadialGradientBrush((x + x + w) / 2, (y + y + h) / 2, 0, 0, w / 2, h / 2, gdColors)
     * this.FillGradientRoundedRect(x, y, w, h, connerRX, connerRY, pBrush)
     */
    FillGradientRoundedRect(x, y, w, h, connerRX, connerRY, pGdBrush) {
        NumPut("float", x, this.drawBoundsPrps, 0)
        NumPut("float", y, this.drawBoundsPrps, 4)
        NumPut("float", x + w, this.drawBoundsPrps, 8)
        NumPut("float", y + h, this.drawBoundsPrps, 12)
        NumPut("float", connerRX, this.drawBoundsPrps, 16)
        NumPut("float", connerRY, this.drawBoundsPrps, 20)
        this.ID2D1RenderTarget.FillRoundedRectangle(this.drawBoundsPrps, pGdBrush)
    }

    DrawEllipse(x, y, w, h, color, strokeWidth := 2, strokeCapStyle := 2, strokeShapeStyle := 0) {
        pBrush := this.GetSavedOrCreateSolidBrush(color)
        pStrokeStyle := this.GetSavedOrCreateStrokeStyle(strokeCapStyle, strokeShapeStyle)
        NumPut("float", x, this.drawBoundsPrps, 0)
        NumPut("float", y, this.drawBoundsPrps, 4)
        NumPut("float", w, this.drawBoundsPrps, 8)
        NumPut("float", h, this.drawBoundsPrps, 12)
        this.ID2D1RenderTarget.DrawEllipse(this.drawBoundsPrps, pBrush, strokeWidth, pStrokeStyle)
    }

    FillEllipse(x, y, w, h, color) {
        pBrush := this.GetSavedOrCreateSolidBrush(color)
        NumPut("float", x, this.drawBoundsPrps, 0)
        NumPut("float", y, this.drawBoundsPrps, 4)
        NumPut("float", w, this.drawBoundsPrps, 8)
        NumPut("float", h, this.drawBoundsPrps, 12)
        this.ID2D1RenderTarget.FillEllipse(this.drawBoundsPrps, pBrush)
    }

    DrawCircle(x, y, radius, color, strokeWidth := 2, strokeCapStyle := 2, strokeShapeStyle := 0) {
        pBrush := this.GetSavedOrCreateSolidBrush(color)
        pStrokeStyle := this.GetSavedOrCreateStrokeStyle(strokeCapStyle, strokeShapeStyle)
        NumPut("float", x, this.drawBoundsPrps, 0)
        NumPut("float", y, this.drawBoundsPrps, 4)
        NumPut("float", radius, this.drawBoundsPrps, 8)
        NumPut("float", radius, this.drawBoundsPrps, 12)
        this.ID2D1RenderTarget.DrawEllipse(this.drawBoundsPrps, pBrush, strokeWidth, pStrokeStyle)
    }

    FillCircle(x, y, radius, color) {
        pBrush := this.GetSavedOrCreateSolidBrush(color)
        NumPut("float", x, this.drawBoundsPrps, 0)
        NumPut("float", y, this.drawBoundsPrps, 4)
        NumPut("float", radius, this.drawBoundsPrps, 8)
        NumPut("float", radius, this.drawBoundsPrps, 12)
        this.ID2D1RenderTarget.FillEllipse(this.drawBoundsPrps, pBrush)
    }

    /**
     * @param {String} svg svg content or svg file path
     * @param {Integer} x svg x of leftTop point
     * @param {Integer} y svg y of leftTop point
     * @param {Integer} w svg width
     * @param {Integer} h svg height
     */
    DrawSvg(svg, x, y, w, h) {
        if FileExist(svg) && RegExReplace(svg, ".*\.(.*)$", "$1") = "svg" {
            DllCall("shlwapi\SHCreateStreamOnFileW", "WStr", svg, "uint", 0, "ptr*", &fs := 0)
            ; convert stream to svgStr for changing width and height
            DllCall("shlwapi\IStream_Size", "ptr", fs, "uint64*", &size := 0)
            DllCall("shlwapi\IStream_Reset", "ptr", fs)
            DllCall("shlwapi\IStream_Read", "ptr", fs, "ptr", buf := Buffer(size), "uint", size, "hresult")
            svg := StrGet(buf, size, "UTF-8")
            ObjRelease(fs)
        }

        if RegExMatch(svg, 'i)^\s*<svg\b[^>]*>') {
            ; replace or insert svg new width and height
            svg := RegExReplace(svg, 'i)(<svg\b[^>]*?)\bwidth\s*=\s*"(?:[^"]*)"', '${1} width="' . w . '"')
            svg := RegExReplace(svg, 'i)(<svg\b[^>]*?)\bheight\s*=\s*"(?:[^"]*)"', '${1} height="' . h . '"')
            if !RegExMatch(svg, 'i)<svg\b[^>]*\bwidth\s*=')
                svg := RegExReplace(svg, 'i)<svg\b', '<svg width="' . w . '"')
            if !RegExMatch(svg, 'i)<svg\b[^>]*\bheight\s*=')
                svg := RegExReplace(svg, 'i)(<svg\b[^>]*?)\b', '${1} height="' . h . '"')
        } else {
            MsgBox("Invailed svg content")
            return 0
        }

        NumPut("float", x, this.bmpDstRect, 0)
        NumPut("float", y, this.bmpDstRect, 4)
        NumPut("float", x + w, this.bmpDstRect, 8)
        NumPut("float", y + h, this.bmpDstRect, 12)
        NumPut("float", 0, this.bmpSrcRect, 0)
        NumPut("float", 0, this.bmpSrcRect, 4)
        NumPut("float", w, this.bmpSrcRect, 8)
        NumPut("float", h, this.bmpSrcRect, 12)
        if pD2dBitmap := this.GetSavedOrCreateSvgBitmap(svg, w, h)
            this.ID2D1RenderTarget.DrawBitmap(pD2dBitmap, this.bmpDstRect, opacity := 1, linear := 1, this.bmpSrcRect)
    }

    DrawImage(imgPath, x := 0, y := 0, w := 0, h := 0, opacity := 1) {
        NumPut("float", x, this.bmpDstRect, 0)
        NumPut("float", y, this.bmpDstRect, 4)
        NumPut("float", x + w, this.bmpDstRect, 8)
        NumPut("float", y + h, this.bmpDstRect, 12)
        NumPut("float", 0, this.bmpSrcRect, 0)
        NumPut("float", 0, this.bmpSrcRect, 4)
        NumPut("float", w, this.bmpSrcRect, 8)
        NumPut("float", h, this.bmpSrcRect, 12)
        if pD2dBitmap := this.GetSavedOrCreateImgBitmap(imgPath)
            this.ID2D1RenderTarget.DrawBitmap(pD2dBitmap, this.bmpDstRect, opacity, linear := 1, this.bmpSrcRect)
    }

    /**
     * @param {String} imgPath
     * @param {Ptr} effectClsid CreateEffect by clsid, like: Direct2D.effectsCLSID["CLSID_D2D1GaussianBlur"]
     * @param {Array} effectProps SetValue of effectProps, like: [{ idx: 0, type: 5, byte: "Float*", data: 3 * 9, dataSize: 4 }, ...]
     * propertyType-> unknown:0, string:1, bool:2, uint32:3, int32:4, float:5, ...,
     * @param {Integer} x
     * @param {Integer} y
     * @param {Integer} w
     * @param {Integer} h
     * @param {Integer} opacity
     */
    DrawImageWithEffect(imgPath, effectCLSID, effectProps, x := 0, y := 0, w := 0, h := 0, opacity := 1) {
        NumPut("float", x, this.bmpDstRect, 0)
        NumPut("float", y, this.bmpDstRect, 4)
        NumPut("float", x + w, this.bmpDstRect, 8)
        NumPut("float", y + h, this.bmpDstRect, 12)
        NumPut("float", 0, this.bmpSrcRect, 0)
        NumPut("float", 0, this.bmpSrcRect, 4)
        NumPut("float", w, this.bmpSrcRect, 8)
        NumPut("float", h, this.bmpSrcRect, 12)
        wicBitmapRT := Direct2D.ID2D1WicBitmapRenderTarget(w, h, this.ID2D1Factory)

        DllCall("gdiplus\GdipCreateBitmapFromFile", "Str", imgPath, "Ptr*", &pGdiBitmap := 0)
        DllCall("gdiplus\GdipGetImageWidth", "ptr", pGdiBitmap, "uint*", &imgW := 0)
        DllCall("gdiplus\GdipGetImageHeight", "ptr", pGdiBitmap, "uint*", &imgH := 0)
        ; https://learn.microsoft.com/windows/win32/direct2d/built-in-effects
        pWICBitmapSource := wicBitmapRT.DrawEffectImage(pGdiBitmap, effectCLSID, effectProps)
        NumPut("uint", 87, this.d2dBmpPrps, 0) ; DXGI_FORMAT_B8G8R8A8_UNORM
        NumPut("uint", 1, this.d2dBmpPrps, 4)  ; D2D1_ALPHA_MODE_PREMULTIPLIED
        pD2dBitmap := this.ID2D1RenderTarget.CreateBitmapFromWicBitmap(pWICBitmapSource, this.d2dBmpPrps)
        this.ID2D1RenderTarget.DrawBitmap(pD2dBitmap, this.bmpDstRect, opacity, linear := 1, this.bmpSrcRect)
        Direct2D.release(pD2dBitmap)
    }

    GetSavedOrCreateSvgBitmap(svgStr, w, h) {
        local bin, cb_size, h_mem := 0, hr, p_buf, p_d2d_bitmap := 0, p_wic_bitmap_source := 0
        local svg_stream := 0, transferred_stream, wic_bitmap_rt := 0

        svgId := Direct2D.fnv1aHash(svgStr)
        if (this.d2dBitmaps.has(svgId))
            return this.d2dBitmaps[svgId]

        try {
            wic_bitmap_rt := Direct2D.ID2D1WicBitmapRenderTarget(w, h, this.ID2D1Factory)

            ; put newDim svg to stream
            bin := Buffer(StrPut(svgStr, "UTF-8"))
            cb_size := StrPut(svgStr, bin, "UTF-8") - 1
            h_mem := DllCall("GlobalAlloc", "uint", 0x2, "uptr", cb_size, "ptr")
            if !h_mem
                throw MemoryError("Failed to allocate memory for the SVG stream.")
            p_buf := DllCall("GlobalLock", "ptr", h_mem, "ptr")
            if !p_buf
                throw Error("Failed to lock memory for the SVG stream.")
            try {
                DllCall("RtlMoveMemory", "ptr", p_buf, "ptr", bin.Ptr, "uptr", cb_size)
            } finally {
                DllCall("GlobalUnlock", "ptr", h_mem)
            }

            hr := DllCall("ole32\CreateStreamOnHGlobal", "ptr", h_mem, "int", fDeleteOnRelease := 1,
                "ptr*", &svg_stream, "HRESULT")
            if svg_stream
                h_mem := 0 ; the stream owns and releases the HGLOBAL
            if hr != 0
                Direct2D.ThrowHResult("CreateStreamOnHGlobal", hr)
            if !svg_stream
                throw Error("CreateStreamOnHGlobal returned no stream.")

            transferred_stream := svg_stream
            svg_stream := 0
            p_wic_bitmap_source := wic_bitmap_rt.GetSvgWICBitmapSource(transferred_stream)
            if !p_wic_bitmap_source
                throw Error("Failed to create the SVG WIC bitmap source.")
            NumPut("uint", 87, this.d2dBmpPrps, 0) ; DXGI_FORMAT_B8G8R8A8_UNORM
            NumPut("uint", 1, this.d2dBmpPrps, 4)  ; D2D1_ALPHA_MODE_PREMULTIPLIED
            p_d2d_bitmap := this.ID2D1RenderTarget.CreateBitmapFromWicBitmap(
                p_wic_bitmap_source, this.d2dBmpPrps)
            if !p_d2d_bitmap
                throw Error("Failed to create the SVG Direct2D bitmap.")
            this.d2dBitmaps[svgId] := p_d2d_bitmap
            p_d2d_bitmap := 0
            return this.d2dBitmaps[svgId]
        } finally {
            if p_d2d_bitmap
                Direct2D.release(p_d2d_bitmap)
            if p_wic_bitmap_source
                Direct2D.release(p_wic_bitmap_source)
            if svg_stream
                ObjRelease(svg_stream)
            if h_mem
                DllCall("GlobalFree", "ptr", h_mem)
            wic_bitmap_rt := 0
        }
    }

    GetSavedOrCreateImgBitmap(imgPath, effect := true) {
        local img_h, img_w, p_d2d_bitmap := 0, p_gdi_bitmap := 0, p_wic_bitmap_source := 0, status
        local wic_bitmap := 0

        if (this.d2dBitmaps.has(imgPath))
            return this.d2dBitmaps[imgPath]

        if (!FileExist(imgPath)) {
            MsgBox(Format("{} does not exist!", imgPath))
            return 0
        }
        try {
            if (status := DllCall("gdiplus\GdipCreateBitmapFromFile", "Str", imgPath, "Ptr*", &p_gdi_bitmap))
                throw Error(Format("GdipCreateBitmapFromFile failed (status {}).", status))
            if (status := DllCall("gdiplus\GdipGetImageWidth", "ptr", p_gdi_bitmap, "uint*", &img_w := 0))
                throw Error(Format("GdipGetImageWidth failed (status {}).", status))
            if (status := DllCall("gdiplus\GdipGetImageHeight", "ptr", p_gdi_bitmap, "uint*", &img_h := 0))
                throw Error(Format("GdipGetImageHeight failed (status {}).", status))

            wic_bitmap := Direct2D.ID2D1WicBitmapRenderTarget(img_w, img_h)
            p_wic_bitmap_source := wic_bitmap.GdiBitmapToWICBitmapSource(
                p_gdi_bitmap, Format32bppPArgb := 0xE200B)
            if !p_wic_bitmap_source
                throw Error("Failed to create the image WIC bitmap source.")
            NumPut("uint", 87, this.d2dBmpPrps, 0) ; DXGI_FORMAT_B8G8R8A8_UNORM
            NumPut("uint", 1, this.d2dBmpPrps, 4)  ; D2D1_ALPHA_MODE_PREMULTIPLIED
            p_d2d_bitmap := this.ID2D1RenderTarget.CreateBitmapFromWicBitmap(
                p_wic_bitmap_source, this.d2dBmpPrps)
            if !p_d2d_bitmap
                throw Error("Failed to create the image Direct2D bitmap.")
            this.d2dBitmaps[imgPath] := p_d2d_bitmap
            p_d2d_bitmap := 0
            return this.d2dBitmaps[imgPath]
        } finally {
            if p_d2d_bitmap
                Direct2D.release(p_d2d_bitmap)
            if p_wic_bitmap_source
                Direct2D.release(p_wic_bitmap_source)
            if p_gdi_bitmap
                DllCall("gdiplus\GdipDisposeImage", "ptr", p_gdi_bitmap)
            wic_bitmap := 0
        }
    }

    GetSavedOrCreateTextFormat(
        fontName,
        fontSize,
        fontWeight := 400,
        fontStyle := 0,
        horizonAlign := 0,
        verticalAlign := 0,
        readingDirection := 0,
        flowDirection := 0
    ) {
        fK := Format(
            "{}|{}|{}|{}|{}|{}|{}|{}",
            fontName,
            fontSize,
            fontWeight,
            fontStyle,
            horizonAlign,
            verticalAlign,
            readingDirection,
            flowDirection
        )
        if this.textFormats.Has(fK)
            return this.textFormats[fK]

        pTextFormat := this.IDWriteFactory.CreateTextFormat(
            fontName,
            fontSize,
            fontWeight,
            fontStyle,
            Map(
                "text_alignment", horizonAlign,
                "paragraph_alignment", verticalAlign,
                "reading_direction", readingDirection,
                "flow_direction", flowDirection
            )
        )
        return this.textFormats[fK] := pTextFormat
    }

    GetTextFormatOption(options, name, fallback) {
        if !options
            return fallback
        if !IsObject(options)
            throw TypeError("Text format options must be an object or 0.")
        if options is Map
            return options.Has(name) ? options[name] : fallback
        return HasProp(options, name) ? options.%name% : fallback
    }

    GetSavedOrCreateSolidBrush(c) {
        bK := Format("{}", c)
        if this.solidBrushes.Has(bK)
            return this.solidBrushes[bK]

        if c <= 0xFFFFFF
            c := c | 0xFF000000
        NumPut("Float", ((c & 0xFF0000) >> 16) / 255, this.colorPrps, 0)  ; R
        NumPut("Float", ((c & 0xFF00) >> 8) / 255, this.colorPrps, 4)  ; G
        NumPut("Float", ((c & 0xFF)) / 255, this.colorPrps, 8)  ; B
        NumPut("Float", (c > 0xFFFFFF ? ((c & 0xFF000000) >> 24) / 255 : 1), this.colorPrps, 12) ; A
        return this.solidBrushes[bK] := this.ID2D1RenderTarget.CreateSolidBrush(this.colorPrps)
    }

    /**
     * @see https://learn.microsoft.com/windows/win32/api/d2d1/ns-d2d1-d2d1_stroke_style_properties
     * @param {Integer} capStyle flat(0) square(1) round(2) triangle(3)
     * @param {Integer} shapeStyle solid(0) dash(1) dot(2) dash_dot(3)
     * @returns {Integer} pStrokeStyle
     */
    GetSavedOrCreateStrokeStyle(capStyle, shapeStyle := 0) {
        sK := Format("{}_{}", capStyle, shapeStyle)
        if this.strokeStyles.Has(sK)
            return this.strokeStyles[sK]

        NumPut("UInt", capStyle, this.strokeStylePrps, 0) ; startCap: D2D1_CAP_STYLE_ROUND(2)
        NumPut("UInt", capStyle, this.strokeStylePrps, 4) ; endCap: D2D1_CAP_STYLE_ROUND(2)
        NumPut("UInt", capStyle, this.strokeStylePrps, 8) ; dashCap: D2D1_CAP_STYLE_ROUND(2)
        NumPut("UInt", capStyle, this.strokeStylePrps, 12) ; lineJoin: D2D1_LINE_JOIN_ROUND(2)
        NumPut("Float", 10.0, this.strokeStylePrps, 16) ; miterLimit
        NumPut("UInt", shapeStyle, this.strokeStylePrps, 20) ; dashStyle: SOLID(0) DASH(1) DOT(2) DASHDOT(3) DASHDOTDOT(4)
        NumPut("Float", -1.0, this.strokeStylePrps, 24) ; dashOffset
        return this.strokeStyles[sK] := this.ID2D1Factory.CreateStrokeStyle(this.strokeStylePrps)
    }

    GetSavedOrCreateGradientdStops(gdColors) {
        gK := ""
        for position, color in gdColors
            gK .= Format("{}_{}", position, color)
        if this.gradientStops.Has(gK)
            return this.gradientStops[gK]

        return this.gradientStops[gK] := this.ID2D1RenderTarget.CreateGradientStopCollection(gdColors)
    }

    SetMatrix3x2fIdentity(pMatrix, offset := 0) {
        NumPut("float", 1, pMatrix, offset + 0)
        NumPut("float", 0, pMatrix, offset + 4)
        NumPut("float", 0, pMatrix, offset + 8)
        NumPut("float", 1, pMatrix, offset + 12)
        NumPut("float", 0, pMatrix, offset + 16)
        NumPut("float", 0, pMatrix, offset + 20)
    }

    SetPosition(x, y, w := 0, h := 0) {
        if !this.hwnd
            return

        this.x := x, this.y := y
        if w != 0 and h != 0
            this.ResizeRenderTarget(w, h)
        this.winRect := [x, y, x + this.width, y + this.height]
        DllCall("MoveWindow", "Uptr", this.hwnd, "int", x, "int", y, "int", this.width, "int", this.height, "char", 1)
    }

    GetDesktopDpiScale() {
        dpiX := this.ID2D1Factory.GetDesktopDpi()
        return dpiX / 96
    }

    GetMousePosRefAttachWin(&x, &y) {
        DllCall("GetCursorPos", "int64*", &cursorPoint := 0)
        x := cursorPoint & 0xffffffff, y := cursorPoint >> 32
        if this.winRect.Length {
            insideWin := x > this.winRect[1] - 1 && x < this.winRect[3] + 1
                && y > this.winRect[2] - 1 && y < this.winRect[4] + 1
            x -= this.winRect[1], y -= this.winRect[2]
            return insideWin
        }
        return 0
    }

    GdipStartUp() {
        if !DllCall("LoadLibraryW", "Wstr", "gdiplus", "UPtr")
            throw Error("Failed to load gdiplus.")

        gdipStartupInput := Buffer(A_PtrSize == 8 ? 24 : 16, 0), NumPut("UInt", Gdip := 1, gdipStartupInput, 0)
        DllCall("gdiplus\GdiplusStartup", "Ptr*", &pToken := 0, "Ptr", gdipStartupInput, "Ptr", 0)
        return pToken
    }

    GdipShutdown(pToken) {
        DllCall("gdiplus\GdiplusShutdown", "Ptr", pToken)
        if hModule := DllCall("GetModuleHandleW", "Wstr", "gdiplus", "UPtr")
            DllCall("FreeLibrary", "Ptr", hModule)
    }
}
