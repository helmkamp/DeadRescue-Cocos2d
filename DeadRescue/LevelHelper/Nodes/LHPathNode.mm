//  This file was generated by LevelHelper
//  http://www.levelhelper.org
//
//  LevelHelperLoader.mm
//  Created by Bogdan Vladu
//  Copyright 2011 Bogdan Vladu. All rights reserved.
////////////////////////////////////////////////////////////////////////////////
//
//  This software is provided 'as-is', without any express or implied
//  warranty.  In no event will the authors be held liable for any damages
//  arising from the use of this software.
//  Permission is granted to anyone to use this software for any purpose,
//  including commercial applications, and to alter it and redistribute it
//  freely, subject to the following restrictions:
//  The origin of this software must not be misrepresented; you must not
//  claim that you wrote the original software. If you use this software
//  in a product, an acknowledgment in the product documentation would be
//  appreciated but is not required.
//  Altered source versions must be plainly marked as such, and must not be
//  misrepresented as being the original software.
//  This notice may not be removed or altered from any source distribution.
//  By "software" the author refers to this code file and not the application 
//  that was used to generate this file.
//
////////////////////////////////////////////////////////////////////////////////
#import "LHPathNode.h"
#import "LevelHelperLoader.h"
#import "LHSettings.h"
#import "LHSprite.h"
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
@interface NSMutableArray (LHMutableArrayExt)

- (void)moveObjectFromIndex:(NSUInteger)from toIndex:(NSUInteger)to;
- (NSArray *)reversedArray;
- (void)reverse;
@end
////////////////////////////////////////////////////////////////////////////////
@implementation NSMutableArray (LHMutableArrayExt)
////////////////////////////////////////////////////////////////////////////////
- (void)moveObjectFromIndex:(NSUInteger)from toIndex:(NSUInteger)to
{
    if (to != from) {
        id obj = [self objectAtIndex:from];
#ifndef LH_ARC_ENABLED
        [obj retain];
#endif
        [self removeObjectAtIndex:from];
        if (to >= [self count]) {
            [self addObject:obj];
        } else {
            [self insertObject:obj atIndex:to];
        }
#ifndef LH_ARC_ENABLED
        [obj release];
#endif
    }
}
////////////////////////////////////////////////////////////////////////////////
- (NSArray *)reversedArray {
    NSMutableArray *array = [NSMutableArray arrayWithCapacity:[self count]];
    NSEnumerator *enumerator = [self reverseObjectEnumerator];
    for (id element in enumerator) {
        [array addObject:element];
    }
    return array;
}
////////////////////////////////////////////////////////////////////////////////
- (void)reverse {
    
    if([self count] == 0)
        return;
    
    NSUInteger i = 0;
    NSUInteger j = [self count] - 1;
    while (i < j) {
        [self exchangeObjectAtIndex:i
                  withObjectAtIndex:j];
        
        ++i;
        --j;
    }
}
@end

////////////////////////////////////////////////////////////////////////////////
@interface LHPathNode (Private)

@end
////////////////////////////////////////////////////////////////////////////////
@implementation LHPathNode

@synthesize isCyclic;
@synthesize restartOtherEnd;
@synthesize axisOrientation;
@synthesize paused;
@synthesize isLine;
@synthesize flipX;
@synthesize flipY;
@synthesize relativeMovement;
////////////////////////////////////////////////////////////////////////////////
-(void) dealloc{		
  //  NSLog(@"PATH NODE DEALLOC");
#ifndef LH_ARC_ENABLED
    [pathPoints release];
    [super dealloc];
#endif

}
////////////////////////////////////////////////////////////////////////////////
-(id) initPathNodeWithPoints:(NSArray *)points onSprite:(LHSprite*)spr
{
	self = [super init];
	if (self != nil)
	{
		speed = 2.2f;
		interval = 0.01f;
		paused = false;
		startAtEndPoint = false;
		isCyclic = false;
		restartOtherEnd = false;
		axisOrientation = 0;
		
        flipX = false;
        flipY = false;
		sprite = spr;
		pathPoints = [[NSMutableArray alloc] initWithArray:points];
		
		currentPoint = 0;
		elapsed = 0.0f;
		isLine = true;
		
        initialAngle = [sprite rotation];
                
        if([pathPoints count] > 0)
            prevPathPosition = LHPointFromValue([pathPoints objectAtIndex:0]); 
	}
	return self;
}
////////////////////////////////////////////////////////////////////////////////
+(float) rotationDegreeFromPoint:(CGPoint)endPoint toPoint:(CGPoint)startPoint
{
	float rotateDegree = atan2f( fabsf(endPoint.x-startPoint.x),
                                 fabsf(endPoint.y-startPoint.y)) * 180.0f / (float)M_PI;
    
	if (endPoint.y>=startPoint.y)
	{
		if (endPoint.x>=startPoint.x){
			rotateDegree = 180.0f + rotateDegree;
		}
		else{
			rotateDegree = 180.0f - rotateDegree;
		}
	}
	else{
		if (endPoint.x<=startPoint.x){
		}
		else{
			rotateDegree = 360.0f - rotateDegree;
		}
	}
	return rotateDegree;
}
////////////////////////////////////////////////////////////////////////////////
-(void) restart{
    currentPoint = 0;
    elapsed = 0.0f;
}
-(void)update:(ccTime)dt
{
    if([[LHSettings sharedInstance] levelPaused])return;
	if(!sprite)return;
	if(paused) return;	
	if(!pathPoints)return;
    
    bool killSelf = false;
    
    if(currentPoint <0 || currentPoint >= [pathPoints count])
        return;
    
	NSValue* ptVal = [pathPoints objectAtIndex:(NSUInteger)currentPoint];
	CGPoint startPosition = LHPointFromValue(ptVal);
            
	int previousPoint = currentPoint -1;
	if(previousPoint < 0){
		previousPoint = 0;
	}
	
	NSValue* prevVal = [pathPoints objectAtIndex:(NSUInteger)previousPoint];
	CGPoint prevPosition = LHPointFromValue(prevVal);
	CGPoint endPosition = startPosition;
	
	float startAngle = [LHPathNode rotationDegreeFromPoint:startPosition toPoint:prevPosition];
	if(currentPoint == 0)
		startAngle = initialAngle+270;
	
	float endAngle = startAngle;
	
	if((currentPoint + 1) < (int)[pathPoints count])
	{
		NSValue* val = [pathPoints objectAtIndex:(NSUInteger)(currentPoint + 1)];
		endPosition = LHPointFromValue(val);                
		endAngle = [LHPathNode rotationDegreeFromPoint:endPosition toPoint:startPosition];
	}
	else {
		if(isCyclic){
			if(!restartOtherEnd)[pathPoints reverse];
            if(flipX)[sprite setFlipX:![sprite flipX]];
            if(flipY)[sprite setFlipY:![sprite flipY]];
			currentPoint = -1;
		}
        
        [[NSNotificationCenter defaultCenter] postNotificationName:LHPathMovementHasEndedNotification
                                                            object:sprite
                                                          userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:sprite, 
                                                                                                        [sprite pathUniqueName],
                                                                                                        [NSNumber numberWithInt:currentPoint], nil]
                                                                                               forKeys:[NSArray arrayWithObjects:LHPathMovementSpriteObject, 
                                                                                                        LHPathMovementUniqueName,
                                                                                                        LHPathMovementPointNumber, nil]]];
        if(!isCyclic)
            killSelf = true;
	}
	
	if(axisOrientation == 1)
		startAngle += 90.0f;
	if(axisOrientation == 1)
		endAngle += 90.0f;
	
	if(startAngle > 360)
		startAngle -=360;
	if(endAngle > 360)
		endAngle-=360;
	
	
	float t = MIN(1.0f, (float)elapsed/interval);
    
	CGPoint deltaP = ccpSub( endPosition, startPosition );

	CGPoint newPos = ccp((startPosition.x + deltaP.x * t), 
						 (startPosition.y + deltaP.y * t));
            
	
	if(startAngle > 270 && startAngle < 360 &&
	   endAngle > 0 && endAngle < 90){
		startAngle -= 360;
	}
	
	if(startAngle > 0 && startAngle < 90 &&
	   endAngle < 360 && endAngle > 270){
		startAngle += 360;
	}
	
	float deltaA = endAngle - startAngle;
	float newAngle = startAngle + deltaA*t;

	if(newAngle > 360)
		newAngle -= 360;
	
	if(nil != sprite)
    {
        CGPoint sprPos = [sprite position];
        
        CGPoint sprDelta = CGPointMake(newPos.x - prevPathPosition.x, newPos.y - prevPathPosition.y);
        
        if(relativeMovement)
            [sprite transformPosition:ccp((sprPos.x + sprDelta.x), 
                                          (sprPos.y + sprDelta.y))];
        else {
            [sprite transformPosition:newPos];
        }
        
        prevPathPosition = newPos;        
    }

	if(axisOrientation != 0){
		[sprite transformRotation:newAngle];
    }
	if(isLine){
        if(axisOrientation != 0){    
            [sprite transformRotation:endAngle];
        }
    }
	
	
	float dist = ccpDistance(prevPathPosition, endPosition);
	
	if(0.001 > dist)
	{
		if(currentPoint + 1 < (int)[pathPoints count])
		{
			elapsed = 0;
			currentPoint += 1;    
            
            [[NSNotificationCenter defaultCenter] postNotificationName:LHPathMovementHasChangedPointNotification
                                                                object:sprite
                                                              userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:sprite, 
                                                                                                            [sprite pathUniqueName],
                                                                                                            [NSNumber numberWithInt:currentPoint], nil]
                                                                                                   forKeys:[NSArray arrayWithObjects:LHPathMovementSpriteObject, 
                                                                                                            LHPathMovementUniqueName,
                                                                                                            LHPathMovementPointNumber, nil]]];
		}
	}
    
	/////////////////////////////////////////

	elapsed += dt;
    
    if(killSelf)
        [sprite stopPathMovement];
}
////////////////////////////////////////////////////////////////////////////////
-(void) setSpeed:(float)value{
    speed = value;
    interval = speed/([pathPoints count]-1);
}
-(float) speed{
    return speed;
}
////////////////////////////////////////////////////////////////////////////////
-(void) setStartAtEndPoint:(bool)val{
    
    startAtEndPoint = val;
    
    if(startAtEndPoint)
		[pathPoints reverse];
}
-(bool) startAtEndPoint{
    return startAtEndPoint;
}
////////////////////////////////////////////////////////////////////////////////
@end
