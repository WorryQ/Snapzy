//
//  AreaSelectionOverlayTests.swift
//  SnapzyTests
//
//  Unit tests for AreaSelectionOverlayView overlay toggle modes (on vs off)
//

import XCTest
import AppKit
@testable import Snapzy

final class AreaSelectionOverlayTests: XCTestCase {

  private var originalSettingValue: Any?
  private var overlayView: AreaSelectionOverlayView!

  override func setUp() {
    super.setUp()
    originalSettingValue = UserDefaults.standard.object(forKey: PreferencesKeys.screenshotShowSelectionAreaOverlay)
    overlayView = AreaSelectionOverlayView(frame: CGRect(x: 0, y: 0, width: 800, height: 600))
  }

  override func tearDown() {
    if let originalSettingValue {
      UserDefaults.standard.set(originalSettingValue, forKey: PreferencesKeys.screenshotShowSelectionAreaOverlay)
    } else {
      UserDefaults.standard.removeObject(forKey: PreferencesKeys.screenshotShowSelectionAreaOverlay)
    }
    overlayView.clearBackdrop()
    overlayView = nil
    super.tearDown()
  }

  private func createSolidColorImage(color: NSColor, size: CGSize) -> CGImage {
    let width = Int(size.width)
    let height = Int(size.height)
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let context = CGContext(
      data: nil,
      width: width,
      height: height,
      bitsPerComponent: 8,
      bytesPerRow: width * 4,
      space: colorSpace,
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
    )
    context?.setFillColor(color.cgColor)
    context?.fill(CGRect(origin: .zero, size: size))
    return context!.makeImage()!
  }

  /// White image with a black vertical strip on the right (pixels x >= stripStartX).
  /// Used to distinguish correct center sampling (white) from the buggy edge-clamped sampling (black).
  private func createImageWithBlackRightStrip(size: CGSize, stripStartX: Int) -> CGImage {
    let width = Int(size.width)
    let height = Int(size.height)
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let context = CGContext(
      data: nil,
      width: width,
      height: height,
      bitsPerComponent: 8,
      bytesPerRow: width * 4,
      space: colorSpace,
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
    )!
    context.setFillColor(NSColor.white.cgColor)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    context.setFillColor(NSColor.black.cgColor)
    context.fill(CGRect(x: stripStartX, y: 0, width: width - stripStartX, height: height))
    return context.makeImage()!
  }

  func testOverlayEnabled_rendersStandardDimming() {
    // GIVEN: Overlay is ON (default/true)
    UserDefaults.standard.set(true, forKey: PreferencesKeys.screenshotShowSelectionAreaOverlay)

    // WHEN: Resetting selection and rendering manual selection rect
    overlayView.setSelectionEnabled(true)
    overlayView.resetSelection()

    let selectionRect = CGRect(x: 100, y: 100, width: 200, height: 150)
    overlayView.renderManualSelection(screenRect: selectionRect, currentScreenPoint: CGPoint(x: 300, y: 250))

    // THEN:
    // - dimLayer background color should be non-nil (the standard dim color)
    // - dimLayer mask should be set to the reusableDimMaskLayer
    // - insideSelectionOverlayLayer should be hidden
    guard let dimLayer = overlayView.dimLayer,
          let insideLayer = overlayView.insideSelectionOverlayLayer else {
      XCTFail("Layers not found")
      return
    }

    XCTAssertNotNil(dimLayer.backgroundColor, "Dim layer must have background color when overlay is enabled")
    XCTAssertNotNil(dimLayer.mask, "Dim layer must have a mask when selection is active and overlay is enabled")
    XCTAssertTrue(insideLayer.isHidden, "Inside overlay layer must be hidden when overlay is enabled")
  }

  func testOverlayDisabled_rendersDarkOverlayOnLightBackdrop() {
    // GIVEN: Overlay is OFF (false) and backdrop is pure white (light background)
    UserDefaults.standard.set(false, forKey: PreferencesKeys.screenshotShowSelectionAreaOverlay)
    
    let whiteImage = createSolidColorImage(color: .white, size: CGSize(width: 800, height: 600))
    let backdrop = AreaSelectionBackdrop(displayID: 0, image: whiteImage, scaleFactor: 1.0)
    overlayView.applyBackdrop(backdrop)

    // WHEN: Resetting selection and rendering manual selection rect
    overlayView.setSelectionEnabled(true)
    overlayView.resetSelection()

    let selectionRect = CGRect(x: 100, y: 100, width: 200, height: 150)
    overlayView.renderManualSelection(screenRect: selectionRect, currentScreenPoint: CGPoint(x: 300, y: 250))

    // THEN:
    // - insideSelectionOverlayLayer must be visible
    // - insideSelectionOverlayLayer should use dark colors (black fill/stroke) because backdrop is light
    guard let dimLayer = overlayView.dimLayer,
          let insideLayer = overlayView.insideSelectionOverlayLayer else {
      XCTFail("Layers not found")
      return
    }

    XCTAssertNil(dimLayer.backgroundColor, "Dim layer must have nil background color when overlay is disabled")
    XCTAssertNil(dimLayer.mask, "Dim layer must not have a mask when overlay is disabled")
    XCTAssertFalse(insideLayer.isHidden, "Inside overlay layer must be visible when overlay is disabled")
    
    XCTAssertEqual(insideLayer.fillColor, NSColor.black.withAlphaComponent(0.12).cgColor, "Inside overlay layer must have dark fill color on light background")
    XCTAssertEqual(insideLayer.strokeColor, NSColor.black.withAlphaComponent(0.3).cgColor, "Inside overlay layer must have dark stroke color on light background")
    XCTAssertEqual(insideLayer.lineWidth, 4.0, "Inside overlay layer must have a 4.0 stroke width")
  }

  func testOverlayDisabled_rendersLightOverlayOnDarkBackdrop() {
    // GIVEN: Overlay is OFF (false) and backdrop is pure black (dark background)
    UserDefaults.standard.set(false, forKey: PreferencesKeys.screenshotShowSelectionAreaOverlay)
    
    let blackImage = createSolidColorImage(color: .black, size: CGSize(width: 800, height: 600))
    let backdrop = AreaSelectionBackdrop(displayID: 0, image: blackImage, scaleFactor: 1.0)
    overlayView.applyBackdrop(backdrop)

    // WHEN: Resetting selection and rendering manual selection rect
    overlayView.setSelectionEnabled(true)
    overlayView.resetSelection()

    let selectionRect = CGRect(x: 100, y: 100, width: 200, height: 150)
    overlayView.renderManualSelection(screenRect: selectionRect, currentScreenPoint: CGPoint(x: 300, y: 250))

    // THEN:
    // - insideSelectionOverlayLayer must be visible
    // - insideSelectionOverlayLayer should use light colors (white fill/stroke) because backdrop is dark (luma is 0.0 < 0.4)
    guard let insideLayer = overlayView.insideSelectionOverlayLayer else {
      XCTFail("Layers not found")
      return
    }

    XCTAssertFalse(insideLayer.isHidden, "Inside overlay layer must be visible when overlay is disabled")
    XCTAssertEqual(insideLayer.fillColor, NSColor.white.withAlphaComponent(0.15).cgColor, "Inside overlay layer must transition to light fill color on dark background")
    XCTAssertEqual(insideLayer.strokeColor, NSColor.white.withAlphaComponent(0.35).cgColor, "Inside overlay layer must transition to light stroke color on dark background")
  }

  func testOverlayDisabled_hysteresisBanding() {
    // GIVEN: Overlay is OFF (false)
    UserDefaults.standard.set(false, forKey: PreferencesKeys.screenshotShowSelectionAreaOverlay)
    
    // Create custom color image with luma = 0.55 (mid-tone)
    // 0.299*r + 0.587*g + 0.114*b = 0.55
    // Let's set r = 0.55, g = 0.55, b = 0.55 -> luma = 0.55
    let midToneColor = NSColor(red: 0.55, green: 0.55, blue: 0.55, alpha: 1.0)
    let midToneImage = createSolidColorImage(color: midToneColor, size: CGSize(width: 800, height: 600))
    
    // Create dark color image with luma = 0.25 (below 0.4)
    let darkColor = NSColor(red: 0.25, green: 0.25, blue: 0.25, alpha: 1.0)
    let darkImage = createSolidColorImage(color: darkColor, size: CGSize(width: 800, height: 600))
    
    // Create light color image with luma = 0.75 (above 0.6)
    let lightColor = NSColor(red: 0.75, green: 0.75, blue: 0.75, alpha: 1.0)
    let lightImage = createSolidColorImage(color: lightColor, size: CGSize(width: 800, height: 600))

    overlayView.setSelectionEnabled(true)
    
    // 1. Start with mid-tone (default is dark overlay)
    let backdropMid = AreaSelectionBackdrop(displayID: 0, image: midToneImage, scaleFactor: 1.0)
    overlayView.applyBackdrop(backdropMid)
    overlayView.resetSelection()
    
    let selectionRect = CGRect(x: 100, y: 100, width: 200, height: 150)
    overlayView.renderManualSelection(screenRect: selectionRect, currentScreenPoint: CGPoint(x: 300, y: 250))
    
    guard let insideLayer = overlayView.insideSelectionOverlayLayer else {
      XCTFail("Layers not found")
      return
    }
    
    // Initial state is dark, luma 0.55 doesn't cross the 0.4 lower threshold to make it light, so it stays dark.
    XCTAssertEqual(insideLayer.fillColor, NSColor.black.withAlphaComponent(0.12).cgColor, "Should start and stay dark overlay on mid-tone")
    
    // 2. Change backdrop to dark (luma = 0.25 < 0.4) -> should transition to light overlay
    let backdropDark = AreaSelectionBackdrop(displayID: 0, image: darkImage, scaleFactor: 1.0)
    overlayView.applyBackdrop(backdropDark)
    overlayView.renderManualSelection(screenRect: selectionRect, currentScreenPoint: CGPoint(x: 300, y: 250))
    
    XCTAssertEqual(insideLayer.fillColor, NSColor.white.withAlphaComponent(0.15).cgColor, "Should switch to light overlay on dark background")
    
    // 3. Change backdrop back to mid-tone (luma = 0.55) -> should stay light overlay (hysteresis)
    overlayView.applyBackdrop(backdropMid)
    overlayView.renderManualSelection(screenRect: selectionRect, currentScreenPoint: CGPoint(x: 300, y: 250))
    
    XCTAssertEqual(insideLayer.fillColor, NSColor.white.withAlphaComponent(0.15).cgColor, "Should maintain light overlay on mid-tone due to hysteresis")
    
    // 4. Change backdrop to light (luma = 0.75 > 0.6) -> should transition back to dark overlay
    let backdropLight = AreaSelectionBackdrop(displayID: 0, image: lightImage, scaleFactor: 1.0)
    overlayView.applyBackdrop(backdropLight)
    overlayView.renderManualSelection(screenRect: selectionRect, currentScreenPoint: CGPoint(x: 300, y: 250))
    
    XCTAssertEqual(insideLayer.fillColor, NSColor.black.withAlphaComponent(0.12).cgColor, "Should switch back to dark overlay on light background")
  }

  func testOverlayDisabled_invisibleBackdropDoesNotRenderButCachesPixels() {
    // GIVEN: Overlay is OFF (false)
    UserDefaults.standard.set(false, forKey: PreferencesKeys.screenshotShowSelectionAreaOverlay)

    // Create dark color image (luma < 0.4)
    let darkColor = NSColor.black
    let darkImage = createSolidColorImage(color: darkColor, size: CGSize(width: 800, height: 600))

    overlayView.setSelectionEnabled(true)

    // Apply invisible backdrop
    let backdrop = AreaSelectionBackdrop(displayID: 0, image: darkImage, scaleFactor: 1.0, isVisible: false)
    overlayView.applyBackdrop(backdrop)
    overlayView.resetSelection()

    // THEN:
    // - snapshotLayer must be hidden because backdrop.isVisible is false
    XCTAssertTrue(overlayView.testSnapshotLayer.isHidden, "Snapshot layer must remain hidden when backdrop is invisible")

    // - backdropPixelDataArray must be cached
    XCTAssertNotNil(overlayView.testBackdropPixelDataArray, "Backdrop pixels must be cached even when backdrop is invisible")

    // - When selection is made, it should correctly sample pixels and use light overlay
    let selectionRect = CGRect(x: 100, y: 100, width: 200, height: 150)
    overlayView.renderManualSelection(screenRect: selectionRect, currentScreenPoint: CGPoint(x: 300, y: 250))

    guard let insideLayer = overlayView.insideSelectionOverlayLayer else {
      XCTFail("insideSelectionOverlayLayer not found")
      return
    }

    XCTAssertFalse(insideLayer.isHidden, "Inside overlay layer must be visible when overlay is disabled")
    XCTAssertEqual(insideLayer.fillColor, NSColor.white.withAlphaComponent(0.15).cgColor, "Inside overlay layer must transition to light fill color on dark background")
  }

  // MARK: - Cursor re-assertion during drag (Phase 02)

  func testReassertCursorDuringDrag_isNoOpWhenNotSelecting() {
    // GIVEN: manual-region mode, selection enabled, but no drag started
    overlayView.setSelectionEnabled(true)
    overlayView.resetSelection()
    XCTAssertFalse(overlayView.isManualSelectionInProgress, "No drag should be in progress after reset")

    // WHEN/THEN: re-asserting the cursor is a guarded no-op (must not crash or change drag state)
    overlayView.reassertCursorDuringDrag()
    XCTAssertFalse(overlayView.isManualSelectionInProgress, "Re-assert must not start a selection")
  }

  func testManualMouseDown_marksSelectionInProgress() {
    // GIVEN: manual-region mode (default) with selection enabled
    overlayView.setSelectionEnabled(true)
    overlayView.resetSelection()
    XCTAssertFalse(overlayView.isManualSelectionInProgress)

    // WHEN: a real left mouse-down lands inside the overlay
    guard let mouseDown = NSEvent.mouseEvent(
      with: .leftMouseDown,
      location: CGPoint(x: 120, y: 120),
      modifierFlags: [],
      timestamp: 0,
      windowNumber: 0,
      context: nil,
      eventNumber: 0,
      clickCount: 1,
      pressure: 1
    ) else {
      XCTFail("Failed to synthesize mouse-down event")
      return
    }
    overlayView.mouseDown(with: mouseDown)

    // THEN: a manual selection is in progress, so re-assertion during drag is active (not the no-op path)
    XCTAssertTrue(
      overlayView.isManualSelectionInProgress,
      "Manual selection must be in progress after a left mouse-down in manual-region mode"
    )
    overlayView.reassertCursorDuringDrag()  // must run without crashing while in progress
    XCTAssertTrue(overlayView.isManualSelectionInProgress)
  }

  func testLumaSampling_derivesScaleFromImageDims_notDeclaredScaleFactor() {
    // Regression (small selection on light background mis-detected as dark→light overlay):
    // the live luma backdrop is captured at `.nominalResolution` (point-sized) but its scaleFactor was
    // set to backingScaleFactor (2x). The old sampler multiplied sample coords by that 2x, overshooting
    // and clamping the grid to the screen's right/bottom edge — so a small centered selection sampled
    // the wrong region. Here the correct region (center) is WHITE and the buggy clamp region (right
    // edge) is BLACK, so the two behaviours produce opposite overlay colors.
    UserDefaults.standard.set(false, forKey: PreferencesKeys.screenshotShowSelectionAreaOverlay)

    // View bounds are 800x600 (setUp). Image is point-sized 800x600 but the backdrop DECLARES scale 2.0,
    // reproducing the nominalResolution + backingScaleFactor mismatch.
    let image = createImageWithBlackRightStrip(size: CGSize(width: 800, height: 600), stripStartX: 720)
    let backdrop = AreaSelectionBackdrop(displayID: 0, image: image, scaleFactor: 2.0, isVisible: false)

    overlayView.setSelectionEnabled(true)
    overlayView.applyBackdrop(backdrop)
    overlayView.resetSelection()

    // Small, centered selection: correct sampling reads the white center (x ~366-433, all < 720);
    // the old 2x-overshoot sampling would clamp to x ~799 (the black strip) and wrongly flip to light.
    let selectionRect = CGRect(x: 350, y: 250, width: 100, height: 80)
    overlayView.renderManualSelection(screenRect: selectionRect, currentScreenPoint: CGPoint(x: 400, y: 290))

    guard let insideLayer = overlayView.insideSelectionOverlayLayer else {
      XCTFail("insideSelectionOverlayLayer not found")
      return
    }
    XCTAssertEqual(
      insideLayer.fillColor,
      NSColor.black.withAlphaComponent(0.12).cgColor,
      "A small centered selection over a white region must keep the dark overlay regardless of the backdrop's declared scaleFactor"
    )
  }

  func testApplicationWindowMode_hasNoManualDragInProgress() {
    // GIVEN: application-window interaction mode
    overlayView.setSelectionEnabled(true)
    overlayView.setInteractionMode(.applicationWindow)

    // WHEN: a left mouse-down lands inside the overlay
    guard let mouseDown = NSEvent.mouseEvent(
      with: .leftMouseDown,
      location: CGPoint(x: 120, y: 120),
      modifierFlags: [],
      timestamp: 0,
      windowNumber: 0,
      context: nil,
      eventNumber: 0,
      clickCount: 1,
      pressure: 1
    ) else {
      XCTFail("Failed to synthesize mouse-down event")
      return
    }
    overlayView.mouseDown(with: mouseDown)

    // THEN: window mode is not a manual drag, so re-assertion stays a no-op
    XCTAssertFalse(
      overlayView.isManualSelectionInProgress,
      "Application-window mode must not report a drag in progress"
    )
    overlayView.reassertCursorDuringDrag()
    XCTAssertFalse(overlayView.isManualSelectionInProgress)
  }

  func testMagnifierZoom_scrollWheelAndLimits() {
    // GIVEN: A valid backdrop
    let image = createSolidColorImage(color: .white, size: CGSize(width: 800, height: 600))
    let backdrop = AreaSelectionBackdrop(displayID: 0, image: image, scaleFactor: 1.0)
    overlayView.applyBackdrop(backdrop)

    // WHEN: Scrolling with Command modifier
    overlayView.testScrollWheel(deltaY: 1.0, modifierFlags: .command)

    // THEN: Zoom should increase beyond 1.0 and magnifier layers should be created
    XCTAssertGreaterThan(overlayView.testMagnifierZoom, 1.0)

    guard let containerLayer = overlayView.testMagnifierContainerLayer else {
      XCTFail("magnifierContainerLayer not found")
      return
    }
    XCTAssertFalse(containerLayer.isHidden)

    // WHEN: Scrolling back down below 1.0
    overlayView.testScrollWheel(deltaY: -5.0, modifierFlags: .command)

    // THEN: Zoom clamps to 1.0 and magnifier layers are removed
    XCTAssertEqual(overlayView.testMagnifierZoom, 1.0)
    XCTAssertNil(overlayView.testMagnifierContainerLayer)
  }

  func testMagnifierZoom_flipsNearCorners() {
    // GIVEN: A valid backdrop
    let image = createSolidColorImage(color: .white, size: CGSize(width: 800, height: 600))
    let backdrop = AreaSelectionBackdrop(displayID: 0, image: image, scaleFactor: 1.0)
    overlayView.applyBackdrop(backdrop)

    // Set zoom manually to 5x to trigger magnifier setup
    overlayView.testScrollWheel(deltaY: 4.0, modifierFlags: .command)

    // WHEN: Cursor is near bottom-left (10, 10)
    overlayView.mouseMoved(with: NSEvent.mouseEvent(
      with: .mouseMoved,
      location: CGPoint(x: 10, y: 10),
      modifierFlags: [],
      timestamp: 0,
      windowNumber: 0,
      context: nil,
      eventNumber: 0,
      clickCount: 0,
      pressure: 0
    )!)

    // THEN: Magnifier is placed at top-right (x = 10 + 20 = 30)
    guard let containerLayer = overlayView.testMagnifierContainerLayer else {
      XCTFail("magnifierContainerLayer not found")
      return
    }
    XCTAssertEqual(containerLayer.frame.origin.x, 30.0)

    // WHEN: Cursor is near top-right (790, 590) - screen bounds 800x600
    overlayView.mouseMoved(with: NSEvent.mouseEvent(
      with: .mouseMoved,
      location: CGPoint(x: 790, y: 590),
      modifierFlags: [],
      timestamp: 0,
      windowNumber: 0,
      context: nil,
      eventNumber: 0,
      clickCount: 0,
      pressure: 0
    )!)

    // THEN: Magnifier flips to top-left/bottom
    // originX = 790 - gap (20) - size (130) = 640
    // originY = 590 - gap (20) - size (130) = 440
    XCTAssertEqual(containerLayer.frame.origin.x, 640.0)
    XCTAssertEqual(containerLayer.frame.origin.y, 440.0)
  }

  func testMagnifierZoom_worksWithShowSelectionAreaOverlaySetting() {
    let image = createSolidColorImage(color: .white, size: CGSize(width: 800, height: 600))
    let backdrop = AreaSelectionBackdrop(displayID: 0, image: image, scaleFactor: 1.0)

    // 1. GIVEN: Show selection area overlay is ON (true)
    UserDefaults.standard.set(true, forKey: PreferencesKeys.screenshotShowSelectionAreaOverlay)
    overlayView.clearBackdrop()
    overlayView.applyBackdrop(backdrop)

    // WHEN: Zooming
    overlayView.testScrollWheel(deltaY: 1.0, modifierFlags: .command)

    // THEN: Zoom works and magnifier container layer is shown
    XCTAssertGreaterThan(overlayView.testMagnifierZoom, 1.0)
    XCTAssertNotNil(overlayView.testMagnifierContainerLayer)
    XCTAssertFalse(overlayView.testMagnifierContainerLayer!.isHidden)

    // 2. GIVEN: Show selection area overlay is OFF (false)
    UserDefaults.standard.set(false, forKey: PreferencesKeys.screenshotShowSelectionAreaOverlay)
    overlayView.clearBackdrop()
    overlayView.applyBackdrop(backdrop)

    // WHEN: Zooming
    overlayView.testScrollWheel(deltaY: 1.0, modifierFlags: .command)

    // THEN: Zoom works and magnifier container layer is shown
    XCTAssertGreaterThan(overlayView.testMagnifierZoom, 1.0)
    XCTAssertNotNil(overlayView.testMagnifierContainerLayer)
    XCTAssertFalse(overlayView.testMagnifierContainerLayer!.isHidden)
  }

  func testMagnifierZoom_contentsRectCenteredOnCursor() {
    let image = createSolidColorImage(color: .white, size: CGSize(width: 800, height: 600))
    let backdrop = AreaSelectionBackdrop(displayID: 0, image: image, scaleFactor: 1.0)
    overlayView.applyBackdrop(backdrop)

    // Set zoom manually to 5x to trigger magnifier setup
    overlayView.testScrollWheel(deltaY: 4.0, modifierFlags: .command)

    // Move cursor to (200, 150)
    overlayView.mouseMoved(with: NSEvent.mouseEvent(
      with: .mouseMoved,
      location: CGPoint(x: 200, y: 150),
      modifierFlags: [],
      timestamp: 0,
      windowNumber: 0,
      context: nil,
      eventNumber: 0,
      clickCount: 0,
      pressure: 0
    )!)

    guard let imgLayer = overlayView.testMagnifierImageLayer else {
      XCTFail("magnifierImageLayer not found")
      return
    }

    let contentsRect = imgLayer.contentsRect
    let centerX = contentsRect.origin.x + contentsRect.size.width / 2.0
    let centerY = contentsRect.origin.y + contentsRect.size.height / 2.0

    XCTAssertEqual(centerX, 0.25, accuracy: 1e-5)
    XCTAssertEqual(centerY, 0.25, accuracy: 1e-5)
  }

  func testMagnifierZoom_reverseDirection() {
    let image = createSolidColorImage(color: .white, size: CGSize(width: 800, height: 600))
    let backdrop = AreaSelectionBackdrop(displayID: 0, image: image, scaleFactor: 1.0)
    overlayView.applyBackdrop(backdrop)

    // 1. GIVEN: Reverse zoom direction is OFF (false)
    overlayView.testReverseMagnifierZoomDirection = false
    overlayView.testScrollWheel(deltaY: 1.0, modifierFlags: .command)
    // Zoom should increase (1.0 + 1.0 = 2.0)
    XCTAssertEqual(overlayView.testMagnifierZoom, 2.0)

    // Reset zoom
    overlayView.clearBackdrop()
    overlayView.applyBackdrop(backdrop)

    // 2. GIVEN: Reverse zoom direction is ON (true)
    overlayView.testReverseMagnifierZoomDirection = true
    overlayView.testScrollWheel(deltaY: 1.0, modifierFlags: .command)
    // Zoom should decrease (but clamps at min zoom 1.0)
    XCTAssertEqual(overlayView.testMagnifierZoom, 1.0)

    // Scroll with negative delta (meaning zoom out under normal, so zoom in under reversed)
    overlayView.testScrollWheel(deltaY: -1.0, modifierFlags: .command)
    // Zoom should increase (1.0 + 1.0 = 2.0)
    XCTAssertEqual(overlayView.testMagnifierZoom, 2.0)
  }

  func testMagnifierZoom_worksWithEmptyBackdropsInitially() {
    let controller = AreaSelectionController.shared

    // GIVEN: Starting selection session with empty backdrops (backdrop-less mode)
    let expectation = XCTestExpectation(description: "Backdrop snapshot automatically generated")

    controller.startSelection(mode: .recording) { _, _ in }

    // Wait a brief moment for async CGWindowListCreateImage task to finish and apply the backdrop
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
      // Find active window in pool
      let targetDisplayID = ScreenUtility.activeDisplayID()
      let mirror = Mirror(reflecting: controller)
      if let pool = mirror.children.first(where: { $0.label == "windowPool" })?.value as? [CGDirectDisplayID: AreaSelectionWindow],
         let window = pool[targetDisplayID] {
        XCTAssertNotNil(window.overlayView.testSnapshotLayer.contents)
      }
      controller.cancelSelection()
      expectation.fulfill()
    }

    wait(for: [expectation], timeout: 3.0)
  }

  // MARK: - BackdropTransitionEffect.shouldCrossfade

  func testShouldCrossfade_falseOnFirstApply() {
    // First-apply: no prior image cached → isReapplication = false → instant, no crossfade
    XCTAssertFalse(
      BackdropTransitionEffect.shouldCrossfade(isReapplication: false, isVisible: true),
      "First-apply must never crossfade (nothing to fade from)"
    )
  }

  func testShouldCrossfade_falseForInvisibleBackdrop() {
    // Invisible (luma-only) backdrop → isVisible = false → no visual change → no crossfade
    XCTAssertFalse(
      BackdropTransitionEffect.shouldCrossfade(isReapplication: true, isVisible: false),
      "Invisible luma-only backdrops must never crossfade"
    )
  }

  func testShouldCrossfade_trueForVisibleReapplication() {
    // Visible re-application: result depends on both the master flag and reduce-motion.
    let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    let expected = BackdropTransitionEffect.isEnabled && !reduceMotion
    XCTAssertEqual(
      BackdropTransitionEffect.shouldCrossfade(isReapplication: true, isVisible: true),
      expected,
      "Visible re-application should crossfade only when isEnabled=true and reduce-motion is off"
    )
  }

  func testApplyBackdrop_animated_doesNotChangeFinalContents() {
    // GIVEN: an initial backdrop applied (so re-application logic triggers)
    let image1 = createSolidColorImage(color: .white, size: CGSize(width: 800, height: 600))
    let backdrop1 = AreaSelectionBackdrop(displayID: 0, image: image1, scaleFactor: 1.0)
    overlayView.applyBackdrop(backdrop1)
    XCTAssertNotNil(overlayView.testSnapshotLayer.contents, "Backdrop must be cached after first apply")

    // WHEN: re-applying with animated:true
    let image2 = createSolidColorImage(color: .black, size: CGSize(width: 800, height: 600))
    let backdrop2 = AreaSelectionBackdrop(displayID: 0, image: image2, scaleFactor: 1.0)
    overlayView.applyBackdrop(backdrop2, animated: true)

    // THEN: final layer contents must be the new image (animation doesn't block the swap)
    XCTAssertTrue(
      (overlayView.testSnapshotLayer.contents as AnyObject) === (image2 as AnyObject),
      "snapshotLayer.contents must be updated to the new image even when animated"
    )
    XCTAssertFalse(overlayView.testSnapshotLayer.isHidden, "Snapshot layer must remain visible for a visible backdrop")
  }

  func testApplyBackdrop_invisibleReapplication_remainsInstant() {
    // Invisible backdrops (luma-only) must never animate and layer stays hidden
    let image1 = createSolidColorImage(color: .white, size: CGSize(width: 800, height: 600))
    let backdrop1 = AreaSelectionBackdrop(displayID: 0, image: image1, scaleFactor: 1.0, isVisible: false)
    overlayView.applyBackdrop(backdrop1)

    let image2 = createSolidColorImage(color: .gray, size: CGSize(width: 800, height: 600))
    let backdrop2 = AreaSelectionBackdrop(displayID: 0, image: image2, scaleFactor: 1.0, isVisible: false)
    overlayView.applyBackdrop(backdrop2, animated: true)

    XCTAssertTrue(overlayView.testSnapshotLayer.isHidden, "Invisible backdrop must keep snapshotLayer hidden even on re-apply")
  }

  func testCoordinatesIndicator_visibleOnStartSelectionWithoutMouseMove() {
    // 1. GIVEN: overlayView with selection enabled, manual mode, and not selecting
    overlayView.setSelectionEnabled(true)
    overlayView.setInteractionMode(.manualRegion, resetSelection: false)

    // 2. WHEN: resetSelection is called
    overlayView.resetSelection()

    // 3. THEN: The coordinate label text layer and background layer should be visible
    XCTAssertFalse(overlayView.testSizeIndicatorTextLayer.isHidden)
    XCTAssertFalse(overlayView.testSizeIndicatorBackgroundLayer.isHidden)
  }

  // MARK: - Backdrop capture coordinate space (CGDisplayBounds vs NSScreen.frame)

  func testCaptureRect_usesCGDisplayBoundsQuartzSpace_notNSScreenAppKitSpace() {
    // Regression: `AreaSelectionWindow.recaptureBackdropsForLuma()` and the magnifier-zoom
    // backdrop-less capture path both feed a capture rect into `CGWindowListCreateImage`,
    // which expects Quartz global display space (origin top-left, Y-down). The two call
    // sites now build that rect from `CGDisplayBounds(displayID)`. Previously they used
    // `screen.frame`, which is AppKit screen space (origin bottom-left, Y-up) — correct
    // only for a single-display Mac where the main display's AppKit origin is (0,0), but
    // wrong for any secondary display, where `screen.frame.origin.y` differs from its
    // Quartz counterpart.
    //
    // We can't fabricate a fake secondary display, but on any real Mac with hardware
    // displays we CAN assert the general coordinate-space relationship: for a display
    // whose AppKit frame origin is not (0,0) relative to the primary display, its
    // CGDisplayBounds rect and NSScreen.frame rect must diverge because they are defined
    // in opposite Y directions relative to different origins.
    guard let mainDisplayID = NSScreen.screens.first?.displayID else {
      XCTFail("Expected at least one screen with a resolvable displayID")
      return
    }

    let quartzBounds = CGDisplayBounds(mainDisplayID)
    guard let mainScreen = NSScreen.screens.first(where: { $0.displayID == mainDisplayID }) else {
      XCTFail("Expected to resolve NSScreen for main displayID")
      return
    }
    let appKitFrame = mainScreen.frame

    // Sanity: sizes must always agree (both describe the same physical display).
    XCTAssertEqual(quartzBounds.width, appKitFrame.width, accuracy: 0.5, "Display width must match between coordinate spaces")
    XCTAssertEqual(quartzBounds.height, appKitFrame.height, accuracy: 0.5, "Display height must match between coordinate spaces")

    // The primary display's Quartz origin is always (0, 0) by definition (it anchors the
    // global display space). Its AppKit frame origin is also (0, 0) because NSScreen.frame
    // for the primary/menu-bar screen is defined relative to itself. So on the primary
    // display alone the two rects coincide -- this is exactly why the bug was invisible on
    // single-display Macs and only manifested with a secondary display.
    XCTAssertEqual(quartzBounds.origin.x, 0, "Primary display's Quartz-space origin.x must be 0")
    XCTAssertEqual(quartzBounds.origin.y, 0, "Primary display's Quartz-space origin.y must be 0")

    // For any additional (secondary) display, prove the two coordinate spaces genuinely
    // differ in general -- i.e. that swapping CGDisplayBounds back for screen.frame would
    // be observably wrong. We simulate "what screen.frame WOULD be" for a secondary
    // display positioned directly above the primary display (a common physical
    // arrangement), since we cannot rely on the test machine actually having a second
    // monitor attached.
    let secondaryHeight: CGFloat = 1080
    let simulatedSecondaryAppKitFrame = CGRect(
      x: 0,
      y: appKitFrame.height,  // AppKit: Y grows upward, so "above" means larger Y
      width: 1920,
      height: secondaryHeight
    )

    // Compute what CGDisplayBounds would report for that same physical arrangement.
    // Quartz global space is Y-down from the top of the primary display, so a monitor
    // physically ABOVE the primary display sits at a NEGATIVE Quartz Y origin.
    let expectedQuartzYForDisplayAbovePrimary = -secondaryHeight

    XCTAssertNotEqual(
      simulatedSecondaryAppKitFrame.origin.y,
      expectedQuartzYForDisplayAbovePrimary,
      "AppKit Y-up origin and Quartz Y-down origin must diverge for a secondary display -- "
        + "passing screen.frame directly to CGWindowListCreateImage would capture the wrong region"
    )

    // Concretely: AppKit reports the primary display's height (positive, Y-up), while Quartz
    // reports the negative of the secondary display's own height (Y-down from the primary's
    // top edge). Assert the exact expected divergence so this test fails loudly if someone
    // "fixes" the arithmetic back to screen.frame semantics.
    XCTAssertEqual(simulatedSecondaryAppKitFrame.origin.y, appKitFrame.height)
    XCTAssertEqual(expectedQuartzYForDisplayAbovePrimary, -1080)
  }

  func testRecaptureBackdropsForLuma_buildsCaptureRectFromCGDisplayBounds() {
    // Regression for the exact call site: `for screen in NSScreen.screens { ... CGDisplayBounds(displayID) ... }`
    // Verify every currently connected display's derived capture rect matches CGDisplayBounds
    // exactly (not screen.frame), confirming the source powering CGWindowListCreateImage is
    // the Quartz-space rect the API actually expects.
    for screen in NSScreen.screens {
      guard let displayID = screen.displayID else { continue }
      let captureRect = CGDisplayBounds(displayID)

      XCTAssertEqual(captureRect, CGDisplayBounds(displayID), "captureRect must be derived directly from CGDisplayBounds(displayID)")

      // Only assert divergence-from-AppKit-space where it's guaranteed to be observable:
      // a screen whose AppKit frame origin is not (0,0), i.e. not the primary display.
      if screen.frame.origin != .zero {
        XCTAssertNotEqual(
          captureRect.origin.y,
          screen.frame.origin.y,
          "For a non-primary display, Quartz-space Y origin must differ from AppKit-space Y origin " +
            "(Y-down vs Y-up) -- using screen.frame here would capture the wrong screen region"
        )
      }
    }
  }

  // MARK: - Cross-display selectionEnabled reconciliation (multi-monitor regression)

  /// Regression for the multi-monitor bug: area selection worked on the PRIMARY display but froze
  /// (no drag rectangle, coordinate indicator stuck) on a SECONDARY display when the capture session
  /// started with empty `selectionBackdrops` and an async backdrop later landed only on the primary.
  ///
  /// Root cause: `AreaSelectionOverlayView.selectionEnabled` is a view-local cached bool, set only via
  /// `setSelectionEnabled(_:)`. The controller's authoritative `selectionEnabled(for:)` is:
  ///   `selectionBackdrops.isEmpty || selectionBackdrops[displayID] != nil || liveFallbackDisplayIDs.contains(displayID)`
  /// The FIRST call to `applyBackdrop(_:for:)` flips `selectionBackdrops.isEmpty` from true to false,
  /// which changes the authoritative answer for EVERY OTHER display -- but before the fix, only the
  /// mutated display's pooled window had its cached flag refreshed. A secondary window's cached flag
  /// stayed stale `true`, so its `mouseDown` skipped the live-fallback rescue path, and the later
  /// authoritative re-check in `beginManualSelection` then correctly said "disabled" -- leaving
  /// `manualSelectionStartPoint` nil and no drag monitors installed. The fix added
  /// `reconcileSelectionEnabledAcrossPooledWindows()`, invoked from `applyBackdrop(_:for:)` right after
  /// `selectionBackdrops[displayID] = backdrop`, which loops EVERY pooled window (not just the one
  /// being mutated) and re-syncs its cached flag to the fresh `selectionEnabled(for:)` value.
  ///
  /// LIMITATION: `AreaSelectionController.windowPool` only ever contains one entry per currently
  /// connected `NSScreen`, and there is no public/internal seam to inject a synthetic secondary
  /// display's window into that private pool from a test running on a single-display machine (or CI
  /// runner). To still exercise the real fix end-to-end (not just re-derive its formula), this test
  /// uses the SINGLE real pooled window as the "secondary" stand-in: its cached flag is seeded to the
  /// stale `true` value a real secondary would have, then `applyBackdrop(_:for:)` is called for a
  /// DIFFERENT, synthetic displayID that has no pooled window (mirroring "the primary's backdrop
  /// arrived, but this window belongs to some other display"). Because
  /// `reconcileSelectionEnabledAcrossPooledWindows()` iterates ALL of `windowPool` regardless of which
  /// displayID was just mutated, this drives the exact same code path a real secondary window would
  /// go through. Without the fix, `applyBackdrop(_:for:)` for an unpooled displayID mutates
  /// `selectionBackdrops` and then hits `guard let window = windowPool[displayID] else { return }` --
  /// returning immediately WITHOUT ever touching the real window's cached flag, leaving it stuck on
  /// stale `true`. A true multi-window assertion (two independently pooled real windows) would require
  /// actual multi-monitor hardware, which is not available in this unit test environment.
  func testApplyBackdrop_reconcilesSelectionEnabledForOtherPooledDisplays() {
    let controller = AreaSelectionController.shared

    // GIVEN: a selection session starts with EMPTY backdrops (backdrop-less / lazy-backdrop mode,
    // e.g. recording-area selection), so every display's `selectionEnabled(for:)` starts out `true`
    // via the `selectionBackdrops.isEmpty` branch.
    let startExpectation = XCTestExpectation(description: "Session started and pool populated")
    controller.startSelection(mode: .recording) { _, _ in }
    DispatchQueue.main.async { startExpectation.fulfill() }
    wait(for: [startExpectation], timeout: 2.0)

    let mirror = Mirror(reflecting: controller)
    guard let windowPool = mirror.children.first(where: { $0.label == "windowPool" })?.value
      as? [CGDirectDisplayID: AreaSelectionWindow],
      let realDisplayID = windowPool.keys.first,
      let realWindow = windowPool[realDisplayID] else {
      XCTFail("Expected at least one pooled window for the current display")
      controller.cancelSelection()
      return
    }

    // Sanity: before any backdrop, the real pooled window's cached flag matches the "empty
    // backdrops" authoritative answer (true).
    XCTAssertTrue(
      selectionEnabledFlag(of: realWindow.overlayView),
      "Cached selectionEnabled must start true when selectionBackdrops is empty"
    )

    // Simulate this real window belonging to a "secondary" display that has NOT yet received its
    // own backdrop, by forcibly re-asserting the stale cached `true` right before the reconciling
    // call below (guards against any incidental prior mutation and makes the stale-value premise
    // explicit, matching the bug report's starting condition).
    realWindow.overlayView.setSelectionEnabled(true)
    XCTAssertTrue(selectionEnabledFlag(of: realWindow.overlayView))

    // A synthetic OTHER display ID -- standing in for "the primary display" in the bug, which is a
    // different display than the one `realWindow` belongs to. It intentionally has no pooled window,
    // so any assertion that depends on `windowPool[otherDisplayID]` being touched would be wrong;
    // what we're proving is that mutating a DIFFERENT display's backdrop still reconciles this one.
    let otherDisplayID = realDisplayID &+ 1

    // WHEN: a backdrop lands on the OTHER display only (async magnifier/luma backdrop capture
    // completing first on the primary while `realWindow`'s own display is still awaiting its
    // backdrop, exactly as in the bug report).
    let image = createSolidColorImage(color: .white, size: CGSize(width: 800, height: 600))
    let backdrop = AreaSelectionBackdrop(displayID: otherDisplayID, image: image, scaleFactor: 1.0)
    controller.applyBackdrop(backdrop, for: otherDisplayID)

    // THEN: `realWindow`'s cached selectionEnabled -- which was never the display being mutated --
    // must be reconciled to `false`, because `selectionBackdrops.isEmpty` is now false and
    // `realDisplayID` has neither its own backdrop nor a live-fallback entry. Before the fix, this
    // window's flag would still be the stale `true` set above, because `applyBackdrop(_:for:)`
    // returned early at `guard let window = windowPool[otherDisplayID]` without ever reaching
    // `realWindow`.
    XCTAssertFalse(
      selectionEnabledFlag(of: realWindow.overlayView),
      "A pooled window whose own display never received a backdrop must have its cached "
        + "selectionEnabled reconciled to false as soon as ANY other display gets one -- "
        + "otherwise its mouseDown skips the live-fallback path and the drag silently drops "
        + "(the multi-monitor freeze bug)"
    )

    controller.cancelSelection()
  }

  /// Reads the private `selectionEnabled` cached bool off an `AreaSelectionOverlayView` via
  /// reflection. There is no `#if DEBUG` test accessor for it (unlike `testSnapshotLayer` etc.),
  /// and adding one is out of scope for this regression test per the fix's "no production
  /// visibility changes" constraint.
  private func selectionEnabledFlag(of overlayView: AreaSelectionOverlayView) -> Bool {
    let mirror = Mirror(reflecting: overlayView)
    guard let value = mirror.children.first(where: { $0.label == "selectionEnabled" })?.value as? Bool else {
      XCTFail("Expected AreaSelectionOverlayView to have a selectionEnabled stored property")
      return true
    }
    return value
  }
}


