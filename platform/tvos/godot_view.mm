/*************************************************************************/
/*  godot_view.mm                                                        */
/*************************************************************************/
/*                       This file is part of:                           */
/*                           GODOT ENGINE                                */
/*                      https://godotengine.org                          */
/*************************************************************************/
/* Copyright (c) 2007-2022 Juan Linietsky, Ariel Manzur.                 */
/* Copyright (c) 2014-2022 Godot Engine contributors (cf. AUTHORS.md).   */
/*                                                                       */
/* Permission is hereby granted, free of charge, to any person obtaining */
/* a copy of this software and associated documentation files (the       */
/* "Software"), to deal in the Software without restriction, including   */
/* without limitation the rights to use, copy, modify, merge, publish,   */
/* distribute, sublicense, and/or sell copies of the Software, and to    */
/* permit persons to whom the Software is furnished to do so, subject to */
/* the following conditions:                                             */
/*                                                                       */
/* The above copyright notice and this permission notice shall be        */
/* included in all copies or substantial portions of the Software.       */
/*                                                                       */
/* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,       */
/* EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF    */
/* MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.*/
/* IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY  */
/* CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,  */
/* TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE     */
/* SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.                */
/*************************************************************************/

#import "godot_view.h"
#import "godot_view_controller.h"

#include "core/os/keyboard.h"
#include "core/project_settings.h"
#include "os_tvos.h"
#include "scene/main/scene_tree.h"
#include "servers/audio_server.h"

#import <OpenGLES/EAGLDrawable.h>
#import <QuartzCore/QuartzCore.h>

#import "godot_view_gesture_recognizer.h"

// For tvOS menu button
#include "rpr/Godot/GodotImplement.h"
#include "roguec/SUtil.h"

//#define LOG_CONTROLLER


@interface GodotView ()
{
	float m_fLastPanX;
	float m_fLastPanY;
	int m_nKeyPresses;
}
@end

@implementation GodotView

- (instancetype)initWithCoder:(NSCoder *)coder {
	self = [super initWithCoder:coder];

	if (self) {
		[self godot_commonInit];
	}

	return self;
}

- (instancetype)initWithFrame:(CGRect)frame {
	self = [super initWithFrame:frame];

	if (self) {
		[self godot_commonInit];
	}

	return self;
}

// Stop animating and release resources when they are no longer needed.
- (void)dealloc {
}

- (void)godot_commonInit {
	// SCE - removed GodotViewGestureRecognizer
	//       Instead we'll add the two recognizers from old Rogue

	// Pan gesture recognizer
	UIPanGestureRecognizer *pPan;
	pPan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(OnPan:)];
	[self addGestureRecognizer:pPan];

	// Add tap gesture recognizers
	UITapGestureRecognizer *pTap;

	// Watch for up/down/left/right taps on the apple remote
	pTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(OnTapUp:)];
	pTap.allowedPressTypes = @[@(UIPressTypeUpArrow)];
	[self addGestureRecognizer:pTap];

	pTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(OnTapDown:)];
	pTap.allowedPressTypes = @[@(UIPressTypeDownArrow)];
	[self addGestureRecognizer:pTap];

	pTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(OnTapLeft:)];
	pTap.allowedPressTypes = @[@(UIPressTypeLeftArrow)];
	[self addGestureRecognizer:pTap];

	pTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(OnTapRight:)];
	pTap.allowedPressTypes = @[@(UIPressTypeRightArrow)];
	[self addGestureRecognizer:pTap];

	// Select on apple remote
	pTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(OnTapSelect:)];
	pTap.allowedPressTypes = @[@(UIPressTypeSelect)];
	[self addGestureRecognizer:pTap];
}

// MARK: - Input

// MARK: Menu Button

- (void)pressesBegan:(NSSet<UIPress *> *)presses withEvent:(UIPressesEvent *)event {
	// Watch out for getting called to early
	if(!SceneTree::get_singleton())
		return;

	// SCE 1/27/2023
	// The problem here is that pressing circle on the DS4 controller (B on an xbox controller)
	// shows up here as a menu button press indistinguishable from the remote menu button
	// We also seperately get the button press from uikit_joypad
	//
	// https://developer.apple.com/library/archive/documentation/ServicesDiscovery/Conceptual/GameControllerPG/ControllingInputontvOS/ControllingInputontvOS.html#//apple_ref/doc/uid/TP40013276-CH7-DontLinkElementID_6
	// Suggests putting game content in GCEventViewController
	// But if you can't, override pressesBegan and don't pass to super class
	//
	// Since we're requiring tvOS 13.0, we can block pressesBegan and check for Menu in uikit_joypad instead

	// SCE: Ask GodotImplement to decide if the Remote Menu button should exit to the home screen

	for(UIPress *pPress in presses)
	{
		if(pPress.type == UIPressTypeMenu)
		{
			GodotImplement* pGodotImplement = GetGodotImplement();
			if(pGodotImplement && pGodotImplement->RemoteMenuShouldExit())
			{
				[super pressesBegan:presses withEvent:event];
				return;
			}
			else
			{
				OS_UIKit::get_singleton()->key(KEY_APPLE_CONTROLLER_MENU, true);
			}
		}
	}

}

- (void)pressesEnded:(NSSet<UIPress *> *)presses withEvent:(UIPressesEvent *)event {
	// Watch out for getting called to early
	if(!SceneTree::get_singleton())
		return;

	// SCE 1/27/2023 - see note in pressesBegan

	// SCE: Ask GodotImplement to decide if the Remote Menu button should exit to the home screen

	for(UIPress *pPress in presses)
	{
		if(pPress.type == UIPressTypeMenu)
		{
			GodotImplement* pGodotImplement = GetGodotImplement();
			if(pGodotImplement && pGodotImplement->RemoteMenuShouldExit())
			{
				[super pressesEnded:presses withEvent:event];
				return;
			}
			else
			{
				OS_UIKit::get_singleton()->key(KEY_APPLE_CONTROLLER_MENU, false);
			}
		}
	}
}

- (void)pressesCancelled:(NSSet<UIPress *> *)presses withEvent:(UIPressesEvent *)event {
	// Watch out for getting called to early
	if(!SceneTree::get_singleton())
		return;

	// SCE 1/27/2023 - see note in pressesBegan

	for(UIPress *pPress in presses)
	{
		if(pPress.type == UIPressTypeMenu)
		{
			GodotImplement* pGodotImplement = GetGodotImplement();
			if(pGodotImplement && pGodotImplement->RemoteMenuShouldExit())
			{
				[super pressesCancelled:presses withEvent:event];
				return;
			}
			else
			{
				OS_UIKit::get_singleton()->key(KEY_APPLE_CONTROLLER_MENU, false);
			}
		}
	}
}

- (void)OnTapUp:(UIGestureRecognizer*)pGestureRecognizer
{
	// Watch out for getting called to early
	if(!SceneTree::get_singleton())
		return;

	// If the keyboardView isFirstResponder, ignore controller input and clear any buttons that were down
	if([GodotView isKeyboardVisible]) {
		OS_UIKit::get_singleton()->release_pressed_events();
		return;
	}

	UITapGestureRecognizer* pTapGestureRecognizer = (UITapGestureRecognizer*)pGestureRecognizer;
	if(pTapGestureRecognizer.state != UIGestureRecognizerStateRecognized)
		return;

	#if defined(LOG_CONTROLLER)
	OutputDebugStringf("[GodotView] OnTapUp\n");
	#endif

	[self PressAndReleaseKey:KEY_UP];

	[self StopFling];
}

- (void)OnTapDown:(UIGestureRecognizer*)pGestureRecognizer
{
	// Watch out for getting called to early
	if(!SceneTree::get_singleton())
		return;

	// If the keyboardView isFirstResponder, ignore controller input and clear any buttons that were down
	if([GodotView isKeyboardVisible]) {
		OS_UIKit::get_singleton()->release_pressed_events();
		return;
	}

	UITapGestureRecognizer* pTapGestureRecognizer = (UITapGestureRecognizer*)pGestureRecognizer;
	if(pTapGestureRecognizer.state != UIGestureRecognizerStateRecognized)
		return;

	#if defined(LOG_CONTROLLER)
	OutputDebugStringf("[GodotView] OnTapDown\n");
	#endif

	[self PressAndReleaseKey:KEY_DOWN];

	[self StopFling];
}

- (void)OnTapLeft:(UIGestureRecognizer*)pGestureRecognizer
{
	// Watch out for getting called to early
	if(!SceneTree::get_singleton())
		return;

	// If the keyboardView isFirstResponder, ignore controller input and clear any buttons that were down
	if([GodotView isKeyboardVisible]) {
		OS_UIKit::get_singleton()->release_pressed_events();
		return;
	}

	UITapGestureRecognizer* pTapGestureRecognizer = (UITapGestureRecognizer*)pGestureRecognizer;
	if(pTapGestureRecognizer.state != UIGestureRecognizerStateRecognized)
		return;

	#if defined(LOG_CONTROLLER)
	OutputDebugStringf("[GodotView] OnTapLeft\n");
	#endif

	[self PressAndReleaseKey:KEY_LEFT];

	[self StopFling];
}

- (void)OnTapRight:(UIGestureRecognizer*)pGestureRecognizer
{
	// Watch out for getting called to early
	if(!SceneTree::get_singleton())
		return;

	// If the keyboardView isFirstResponder, ignore controller input and clear any buttons that were down
	if([GodotView isKeyboardVisible]) {
		OS_UIKit::get_singleton()->release_pressed_events();
		return;
	}

	UITapGestureRecognizer* pTapGestureRecognizer = (UITapGestureRecognizer*)pGestureRecognizer;
	if(pTapGestureRecognizer.state != UIGestureRecognizerStateRecognized)
		return;

	#if defined(LOG_CONTROLLER)
	OutputDebugStringf("[GodotView] OnTapRight\n");
	#endif

	[self PressAndReleaseKey:KEY_RIGHT];

	[self StopFling];
}

- (void)OnTapSelect:(UIGestureRecognizer*)pGestureRecognizer
{
	// Watch out for getting called to early
	if(!SceneTree::get_singleton())
		return;

	// If the keyboardView isFirstResponder, ignore controller input and clear any buttons that were down
	if([GodotView isKeyboardVisible]) {
		OS_UIKit::get_singleton()->release_pressed_events();
		return;
	}

	UITapGestureRecognizer* pTapGestureRecognizer = (UITapGestureRecognizer*)pGestureRecognizer;
	if(pTapGestureRecognizer.state != UIGestureRecognizerStateRecognized)
		return;

	#if defined(LOG_CONTROLLER)
	OutputDebugStringf("[GodotView] OnTapSelect\n");
	#endif

	[self PressAndReleaseButton:0];

	[self StopFling];
}

- (void)OnPan:(UIGestureRecognizer*)pGestureRecognizer
{
	// Watch out for getting called to early
	if(!SceneTree::get_singleton())
		return;

	// If the keyboardView isFirstResponder, ignore controller input and clear any buttons that were down
	if([GodotView isKeyboardVisible]) {
		OS_UIKit::get_singleton()->release_pressed_events();
		return;
	}

	UIPanGestureRecognizer* pPanGestureRecognizer = (UIPanGestureRecognizer*)pGestureRecognizer;

	CGPoint ptTranslation = [pPanGestureRecognizer translationInView:nil];
	CGPoint ptVelocity = [pPanGestureRecognizer velocityInView:nil];
	CGPoint ptTouch = pPanGestureRecognizer.numberOfTouches ? [pPanGestureRecognizer locationOfTouch:0 inView:nil] : CGPointZero;

	if(pPanGestureRecognizer.state == UIGestureRecognizerStateBegan)
	{
		#if defined(LOG_CONTROLLER)
		OutputDebugStringf("[GodotView OnPan] UIGestureRecognizerStateBegan\n");
		#endif
		m_fLastPanX = ptTouch.x;
		m_fLastPanY = ptTouch.y;
		m_nKeyPresses = 0;
	}
	else if(pPanGestureRecognizer.state == UIGestureRecognizerStateEnded)
	{
		#if defined(LOG_CONTROLLER)
		OutputDebugStringf("[GodotView OnPan] UIGestureRecognizerStateEnded\n");
		#endif
		return;
	}

	// If it's a fast fling, we want to send a FlingEvent instead of a keypress
	// SScrollBox, for example, can listen for it
	// In testing, I got velocity 1420 to 5694 trying to move slow
	// then 6005 to 14005 trying to move fast
	// So maybe 6000 or 7000 is a good threshold
	// Testing on iPad, I got a velocity around 1000 in SScrollBox::Fling
	// So maybe scaling the threshold to 1000 is reasonable
	#define FLING_VELOCITY_THRESHOLD (6000.0f)
	#define FLING_VELOCITY_SCALE_TO (1000.0f)

	bool bSentFling = false;
	float fVelocityX = ptVelocity.x;
	float fVelocityY = ptVelocity.y;
	if(fabs(fVelocityX) > FLING_VELOCITY_THRESHOLD || fabs(fVelocityY) > FLING_VELOCITY_THRESHOLD)
	{
		// Scale velocity to something you might see on a touch screen
		fVelocityX = FLING_VELOCITY_SCALE_TO * fVelocityX / FLING_VELOCITY_THRESHOLD;
		fVelocityY = FLING_VELOCITY_SCALE_TO * fVelocityY / FLING_VELOCITY_THRESHOLD;

		// We need to invert the Fling so that it's moving
		// in the same direction as the keypresses we're sending
		fVelocityX = -fVelocityX;
		fVelocityY = -fVelocityY;

		// Send the event
		GodotImplement* pGodotImplement = GetGodotImplement();
		if(pGodotImplement)
			pGodotImplement->SendFlingEvent(fVelocityX, fVelocityY);

		bSentFling = true;
	}

	float fThreshold;

	if(m_nKeyPresses == 0)
	{
		fThreshold = 100.0f;
	}
	else if(m_nKeyPresses == 1)
	{
		fThreshold = 500.0f;
	}
	else
	{
		fThreshold = 300.0f;
	}

	bool bUp = false;
	bool bDown = false;
	bool bLeft = false;
	bool bRight = false;

	float dx = ptTouch.x - m_fLastPanX;
	float dy = ptTouch.y - m_fLastPanY;

	if(dx >= fThreshold)
	{
		bRight = true;
		m_fLastPanX += fThreshold;
		[self PressAndReleaseKey:KEY_RIGHT];
	}

	if(dx <= -fThreshold)
	{
		bLeft = true;
		m_fLastPanX -= fThreshold;
		[self PressAndReleaseKey:KEY_LEFT];
	}

	if(dy >= fThreshold)
	{
		bDown = true;
		m_fLastPanY += fThreshold;
		[self PressAndReleaseKey:KEY_DOWN];
	}

	if(dy <= -fThreshold)
	{
		bUp = true;
		m_fLastPanY -= fThreshold;
		[self PressAndReleaseKey:KEY_UP];
	}

	if(bRight || bLeft || bDown || bUp)
	{
		m_nKeyPresses += 1;

		// Cancel any in progress fling on taps
		// Unless we just sent a fling event
		if(!bSentFling)
			[self StopFling];
	}

	#if defined(LOG_CONTROLLER)
	OutputDebugStringf("[GodotView OnPan][%i] Touch: %g, %g    Translation: %g, %g    Velocity: %g, %g\n",
		pPanGestureRecognizer.state,
		ptTouch.x, ptTouch.y,
		ptTranslation.x, ptTranslation.y,
		ptVelocity.x, ptVelocity.y);
	#endif

	#if 0
	OutputDebugStringf("[GodotView OnPan] %i %f T:%-7.2f, %-7.2f L:%-7.2f, %-7.2f D:%f, %G, %s%s%s%s\n",
		m_nKeyPresses,
		fThreshold,
		ptTouch.x, ptTouch.y,
		m_fLastPanX, m_fLastPanY,
		dx, dy,
		bRight ? "R" : "",
		bLeft ? "L" : "",
		bDown ? "D" : "",
		bUp ? "U" : ""
		);
	#endif
}

+ (UIViewController*) topMostController
{
    UIViewController *topController = [UIApplication sharedApplication].keyWindow.rootViewController;

    while (topController.presentedViewController) {
        topController = topController.presentedViewController;
    }

    return topController;
}

+ (bool) isKeyboardVisible
{
	UIViewController *topController = [GodotView topMostController];

	// If the tvOS keyboard is up, the top controller is "UISystemInputController", which is undocumented.
	// So we'll check for GodotViewController instead.

	if ([topController isKindOfClass:[GodotViewController class]]) {
		return false;
	}

	return true;
}

- (void)PressAndReleaseKey:(uint32_t)p_key
{
	OS_UIKit::get_singleton()->key(p_key, true);
	OS_UIKit::get_singleton()->key(p_key, false);
}

- (void)PressAndReleaseButton:(uint32_t)p_button
{
	OS_UIKit::get_singleton()->joy_button(0, p_button, true);
	OS_UIKit::get_singleton()->joy_button(0, p_button, false);
}

- (void)StopFling
{
	GodotImplement* pGodotImplement = GetGodotImplement();
	if(pGodotImplement)
		pGodotImplement->StopFling();
}

@end
