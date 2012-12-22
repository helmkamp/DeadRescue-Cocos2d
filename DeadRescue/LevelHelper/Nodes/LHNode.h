//
//  LHNode.h
//  
//
//  Created by Bogdan Vladu on 4/2/12.
//  Copyright (c) 2012 Bogdan Vladu. All rights reserved.
//

#import "CCNode.h"
#import "lhConfig.h"
#ifdef LH_USE_BOX2D
#include "Box2D.h"
#endif

@interface LHNode : CCNode
{
    NSString* uniqueName;
    
#ifdef LH_USE_BOX2D
    b2Body* body;
#endif
}

+(id)nodeWithDictionary:(NSDictionary*)dictionary;

#ifdef LH_USE_BOX2D
-(void)setBody:(b2Body*)body;
-(b2Body*)body;
#endif
@end
