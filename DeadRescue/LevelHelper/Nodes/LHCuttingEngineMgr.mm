//
//  LHCuttingEngineMgr.m
//  LevelHelperExplodingSprites
//
//  Created by Bogdan Vladu on 3/10/12.
//  Copyright (c) 2012 Bogdan Vladu. All rights reserved.
//
#import "LHCuttingEngineMgr.h"

#ifdef LH_USE_BOX2D
#import "LHSprite.h"
#import "LHJoint.h"
#import "LevelHelperLoader.h"

// Include STL vector class.
#include <map>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>

#import "cocos2d.h"
// Typedef an STL vector of vertices which are used to represent
// a polygon/contour and a series of triangles.
typedef std::vector< b2Vec2 > Vector2dVector;

class Triangulate
{
public:

// triangulate a contour/polygon, places results in STL vector
// as series of triangles.
static bool Process(const Vector2dVector &contour,
                    Vector2dVector &result);

// compute area of a contour/polygon
static float Area(const Vector2dVector &contour);

// decide if point Px/Py is inside triangle defined by
// (Ax,Ay) (Bx,By) (Cx,Cy)
static bool InsideTriangle(float Ax, float Ay,
                           float Bx, float By,
                           float Cx, float Cy,
                           float Px, float Py);


private:
static bool Snip(const Vector2dVector &contour,int u,int v,int w,int n,int *V);

};


//#endif

/**************************************************************************/
/*** END OF HEADER FILE TRIANGULATE.H BEGINNING OF CODE TRIANGULATE.CPP ***/
/**************************************************************************/


static const float EPSILON=0.0000000001f;

float Triangulate::Area(const Vector2dVector &contour)
{
    
    int n = (int)contour.size();
    
    float A=0.0f;
    
    for(int p=n-1,q=0; q<n; p=q++)
    {
        A+= contour[p].x*contour[q].y - contour[q].x*contour[p].y;
    }
    return A*0.5f;
}

/*
 InsideTriangle decides if a point P is Inside of the triangle
 defined by A, B, C.
 */
bool Triangulate::InsideTriangle(float Ax, float Ay,
                                 float Bx, float By,
                                 float Cx, float Cy,
                                 float Px, float Py)

{
    float ax, ay, bx, by, cx, cy, apx, apy, bpx, bpy, cpx, cpy;
    float cCROSSap, bCROSScp, aCROSSbp;
    
    ax = Cx - Bx;  ay = Cy - By;
    bx = Ax - Cx;  by = Ay - Cy;
    cx = Bx - Ax;  cy = By - Ay;
    apx= Px - Ax;  apy= Py - Ay;
    bpx= Px - Bx;  bpy= Py - By;
    cpx= Px - Cx;  cpy= Py - Cy;
    
    aCROSSbp = ax*bpy - ay*bpx;
    cCROSSap = cx*apy - cy*apx;
    bCROSScp = bx*cpy - by*cpx;
    
    return ((aCROSSbp >= 0.0f) && (bCROSScp >= 0.0f) && (cCROSSap >= 0.0f));
};

bool Triangulate::Snip(const Vector2dVector &contour,int u,int v,int w,int n,int *V)
{
    int p;
    float Ax, Ay, Bx, By, Cx, Cy, Px, Py;
    
    Ax = contour[V[u]].x;
    Ay = contour[V[u]].y;
    
    Bx = contour[V[v]].x;
    By = contour[V[v]].y;
    
    Cx = contour[V[w]].x;
    Cy = contour[V[w]].y;
    
    if ( EPSILON > (((Bx-Ax)*(Cy-Ay)) - ((By-Ay)*(Cx-Ax))) ) return false;
    
    for (p=0;p<n;p++)
    {
        if( (p == u) || (p == v) || (p == w) ) continue;
        Px = contour[V[p]].x;
        Py = contour[V[p]].y;
        if (InsideTriangle(Ax,Ay,Bx,By,Cx,Cy,Px,Py)) return false;
    }
    
    return true;
}

bool Triangulate::Process(const Vector2dVector &contour,Vector2dVector &result)
{
    /* allocate and initialize list of Vertices in polygon */
    
    int n = (int)contour.size();
    if ( n < 3 ) return false;
    
    int *V = new int[n];
    
    /* we want a counter-clockwise polygon in V */
    
    if ( 0.0f < Area(contour) )
        for (int v=0; v<n; v++) V[v] = v;
    else
        for(int v=0; v<n; v++) V[v] = (n-1)-v;
    
    int nv = n;
    
    /*  remove nv-2 Vertices, creating 1 triangle every time */
    int count = 2*nv;   /* error detection */
    
    for(int m=0, v=nv-1; nv>2; )
    {
        /* if we loop, it is probably a non-simple polygon */
        if (0 >= (count--))
        {
            //** Triangulate: ERROR - probable bad polygon!
            return false;
        }
        
        /* three consecutive vertices in current polygon, <u,v,w> */
        int u = v  ; if (nv <= u) u = 0;     /* previous */
        v = u+1; if (nv <= v) v = 0;     /* new v    */
        int w = v+1; if (nv <= w) w = 0;     /* next     */
        
        if ( Snip(contour,u,v,w,nv,V) )
        {
            int a,b,c,s,t;
            
            /* true names of the vertices */
            a = V[u]; b = V[v]; c = V[w];
            
            /* output Triangle */
            result.push_back( contour[a] );
            result.push_back( contour[b] );
            result.push_back( contour[c] );
            
            m++;
            
            /* remove v from remaining polygon */
            for(s=v,t=v+1;t<nv;s++,t++) V[s] = V[t]; nv--;
            
            /* resest error detection counter */
            count = 2*nv;
        }
    }
    
    delete V;
    
    return true;
}

int comparator(const void *a, const void *b) {
    const b2Vec2 *va = (const b2Vec2 *)a;
    const b2Vec2 *vb = (const b2Vec2 *)b;
    
    if (va->x > vb->x) {
        return 1;
    } else if (va->x < vb->x) {
        return -1;
    }
    return 0;
}

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
//a is point 1 on the line - b is point 2 on the line
//c is the point we want to check
bool isLeft(b2Vec2 a, b2Vec2 b, b2Vec2 c)
{
    return ((b.x - a.x)*(c.y - a.y) - (b.y - a.y)*(c.x - a.x)) > 0;
}
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
class AllBodiesRayCastCallback : public b2RayCastCallback{
public:
AllBodiesRayCastCallback(){    
}

float32 ReportFixture(b2Fixture* fixture, const b2Vec2& point,
                      const b2Vec2& normal, float32 fraction){

#ifndef LH_ARC_ENABLED
    id userData = (id)fixture->GetBody()->GetUserData();
#else
    id userData = (__bridge id)fixture->GetBody()->GetUserData();
#endif
    if ([userData isKindOfClass:[LHSprite class]]) {
        rayCastInfo[fixture->GetBody()] = point;
    }
    
    return 1;//go to all other points
}
std::map<b2Body*, b2Vec2> rayCastInfo;
};
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
class BodiesInAABBCallback : public b2QueryCallback
{
public:
	virtual ~BodiesInAABBCallback() {}
    
	/// Called for each fixture found in the query AABB.
	/// @return false to terminate the query.
	bool ReportFixture(b2Fixture* fixture)
    {
        queryInfo[fixture->GetBody()] = fixture;
        return true;
    }
    std::map<b2Body*, b2Fixture*> queryInfo;
};
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
@implementation LHCuttingEngineMgr

//this code is an extension from here http://www.cocos2d-iphone.org/forum/topic/2079
-(void) explodeSpritesInRadius:(float)radius
                     withForce:(float)maxForce
                      position:(CGPoint)pos
                       inWorld:(b2World*)world
                       suction:(bool)doSuction
{
    BodiesInAABBCallback callback;
    b2AABB aabb;
    
    aabb.lowerBound = [LevelHelperLoader pointsToMeters:ccp(pos.x - radius, pos.y - radius)];
    aabb.upperBound = [LevelHelperLoader pointsToMeters:ccp(pos.x + radius, pos.y + radius)];

    world->QueryAABB(&callback, aabb);
    
    std::map<b2Body*, b2Fixture*>::iterator it;
    
    for(it = callback.queryInfo.begin(); it != callback.queryInfo.end(); ++it)
    {
        b2Body* b = (*it).first;    
    
		b2Vec2 b2TouchPosition = [LevelHelperLoader pointsToMeters:pos];
		b2Vec2 b2BodyPosition = b2Vec2(b->GetPosition().x, b->GetPosition().y);
        
		float maxDistance = radius/[LevelHelperLoader meterRatio];
		CGFloat distance = 0.0f;
		CGFloat strength = 0.0f;
		float force = 0.0f;
		CGFloat angle = 0.0f;
        
		if(doSuction) 
		{
			distance = b2Distance(b2BodyPosition, b2TouchPosition);
			if(distance > maxDistance) distance = maxDistance - 0.01f;
			// Get the strength
			//strength = distance / maxDistance; // Uncomment and reverse these two. and ones further away will get more force instead of less
			strength = (maxDistance - distance) / maxDistance; // This makes it so that the closer something is - the stronger, instead of further
			force  = strength * maxForce;
            
			// Get the angle
			angle = atan2f(b2TouchPosition.y - b2BodyPosition.y, b2TouchPosition.x - b2BodyPosition.x);
            
            //IF YOU ARE USING VERY LAST VERSION OF BOX2D - ADD THE true argument at the end of this function call
            b->ApplyForce(b2Vec2(cosf(angle) * force, sinf(angle) * force), b->GetPosition());//, true);
		}
		else
		{
			distance = b2Distance(b2BodyPosition, b2TouchPosition);
			if(distance > maxDistance) distance = maxDistance - 0.01f;
            
			strength = (maxDistance - distance) / maxDistance;
			force = strength * maxForce;
			angle = atan2f(b2BodyPosition.y - b2TouchPosition.y, b2BodyPosition.x - b2TouchPosition.x);
            
            //IF YOU ARE USING VERY LAST VERSION OF BOX2D - ADD THE true argument at the end of this function call
            b->ApplyForce(b2Vec2(cosf(angle) * force, sinf(angle) * force), b->GetPosition());//, true);
		}
	}
}


+ (LHCuttingEngineMgr*)sharedInstance{
	static id sharedInstance = nil;
	if (sharedInstance == nil){
		sharedInstance = [[LHCuttingEngineMgr alloc] init];
	}
    return sharedInstance;
}
//------------------------------------------------------------------------------
-(void)dealloc
{
#ifndef LH_ARC_ENABLED

    [spritesPreviouslyCut release];
	[super dealloc];
#endif
}
//------------------------------------------------------------------------------
- (id)init
{
	self = [super init];
	if (self != nil) {
        spritesPreviouslyCut = [[NSMutableSet alloc] init];
        
#if COCOS2D_VERSION >= 0x00020000
        mShaderProgram = [[CCShaderCache sharedShaderCache] programForKey:kCCShader_PositionTexture];
        mColorLocation = glGetUniformLocation( mShaderProgram->program_, "u_color");
#endif

        
	}
	return self;
}
//------------------------------------------------------------------------------
-(void)destroyAllPrevioslyCutSprites{
    
    for(LHSprite* spr in spritesPreviouslyCut){
        [spr removeSelf];
    }
    [spritesPreviouslyCut removeAllObjects];
}
//------------------------------------------------------------------------------
-(NSArray*)sprites{
    
    NSArray* array = [spritesPreviouslyCut allObjects];
    [spritesPreviouslyCut removeAllObjects];
    return array;
}
//------------------------------------------------------------------------------
-(LHSprite *)spriteWithVertices:(CGPoint[])vertices 
                         verticesCount:(int)count
                         oldSprite:(LHSprite*)oldSprite{

    if(oldSprite == nil)
    {
        NSLog(@"OLD SPRITE WAS NIL");
        return nil;
    }
    
    if(![oldSprite isKindOfClass:[LHSprite class]])
    {
        NSLog(@"OLD SPRITE IS NOT LHSprite");
        return nil;
    }

    CGRect oldRect = [oldSprite originalRect];
    
    CCTexture2D* oldTexture = [[CCTextureCache sharedTextureCache] addImage:[oldSprite imageFile]];
    
    CCSprite* tempOrigSprite = [CCSprite spriteWithTexture:oldTexture rect:oldRect];
    
    [tempOrigSprite setFlipX:YES];
    [tempOrigSprite setFlipY:YES];
    
    CCRenderTexture *justSprTx = [CCRenderTexture renderTextureWithWidth:(int)oldRect.size.width
                                                                  height:(int)oldRect.size.height];
    [justSprTx beginWithClear:1 g:1 b:1 a:0];
    
    [tempOrigSprite draw];
    
    [justSprTx end];
        
    CCRenderTexture *myCutTexture = [CCRenderTexture renderTextureWithWidth:(int)oldRect.size.width
                                                                     height:(int)oldRect.size.height];
    [myCutTexture beginWithClear:1 g:1 b:1 a:0];
    
#if COCOS2D_VERSION >= 0x00020000 
    
    ccGLEnable( glServerState_ );	
    [mShaderProgram use];
    
#if COCOS2D_VERSION >= 0x00020100
    [mShaderProgram setUniformsForBuiltins];
#else
    [mShaderProgram setUniformForModelViewProjectionMatrix];
#endif
    
	ccVertex2F* verts = new ccVertex2F[count];
	for( int i=0;i<count;i++) {
		verts[i].x = vertices[i].x;//*CC_CONTENT_SCALE_FACTOR();
		verts[i].y = vertices[i].y;//*CC_CONTENT_SCALE_FACTOR();
	}

    ccTex2F* uvs = new ccTex2F[count];
	for( int i=0;i<count;i++) {
		uvs[i].u = (vertices[i].x/(float)justSprTx.sprite.texture.pixelsWide)*CC_CONTENT_SCALE_FACTOR();
		uvs[i].v = (vertices[i].y/(float)justSprTx.sprite.texture.pixelsHigh)*CC_CONTENT_SCALE_FACTOR();
	}

    ccGLBindTexture2D( justSprTx.sprite.texture.name );
    
	[mShaderProgram setUniformLocation:(NSUInteger)mColorLocation
                                withF1:1.0f
                                    f2:1.0f
                                    f3:1.0f
                                    f4:1.0f];
    
    glVertexAttribPointer(kCCVertexAttrib_TexCoords, 2, GL_FLOAT, GL_FALSE, 0, uvs);
	glVertexAttribPointer(kCCVertexAttrib_Position, 2, GL_FLOAT, GL_FALSE, 0, verts);
	glDrawArrays(GL_TRIANGLES, 0, count);
    
	CC_INCREMENT_GL_DRAWS(1);
    delete[] uvs;
    delete[] verts;
    
#else
    glEnable(GL_TEXTURE_2D);		
    glBindTexture(GL_TEXTURE_2D, justSprTx.sprite.texture.name);//sprOrigFrm.texture.name);
    
    
    ccVertex2F* verts = new ccVertex2F[count];
	for( int i=0;i<count;i++) {
		verts[i].x = vertices[i].x*CC_CONTENT_SCALE_FACTOR();
		verts[i].y = vertices[i].y*CC_CONTENT_SCALE_FACTOR();
	}
    
    ccTex2F* uv = new ccTex2F[count];
    for(int k = 0; k < count; ++k){
        
        uv[k].u = (vertices[k].x/(float)justSprTx.sprite.texture.pixelsWide)*CC_CONTENT_SCALE_FACTOR();
        uv[k].v = (vertices[k].y/(float)justSprTx.sprite.texture.pixelsHigh)*CC_CONTENT_SCALE_FACTOR();
    }
    
    ccColor4F* clr = new ccColor4F[count];
    for(int i = 0; i<count; ++i)
    {
        clr[i] = (ccColor4F){1.0f, 1.0f, 1.0f, 1.0f};
    }

    
    
    glTexCoordPointer(2, GL_FLOAT, 0, uv);
    glColorPointer(4, GL_FLOAT, 0, clr);
    glVertexPointer(2, GL_FLOAT, 0, verts);
    glDrawArrays(GL_TRIANGLES, 0, count);
    delete[] uv;
    delete[] clr;
    delete[] verts;
    
#endif
    
    [myCutTexture end];
    
    LHSprite* sprCut = [LHSprite spriteWithTexture:myCutTexture.sprite.texture];
    
    if(sprCut)
    {
        [sprCut setOriginalRect:oldRect];
        [sprCut setImageFile:[oldSprite imageFile]];
        [sprCut setTag:[oldSprite tag]];
        [sprCut setOpacity:[oldSprite opacity]];
        [sprCut setColor:[oldSprite color]];
        
        [sprCut setScaleX:[oldSprite scaleX]];
        [sprCut setScaleY:[oldSprite scaleY]];
        
        [sprCut setUsePhysicsForTouches:YES];
        
        static long long createdSprites = 0;
        [sprCut setUniqueName:[NSString stringWithFormat:@"%lld", createdSprites]];
        
        ++createdSprites;
        
        
#if COCOS2D_VERSION >= 0x00020000 
        if(oldSprite.batchNode)
#else
        if([oldSprite usesBatchNode])
#endif
        {
            LHLayer* layer = (LHLayer*)[[oldSprite parent] parent];
            [layer addChild:sprCut];
        }
        else {
            LHLayer* layer = (LHLayer*)[oldSprite parent];
            [layer addChild:sprCut];
        }
        
        [spritesPreviouslyCut addObject:sprCut];
        [spritesPreviouslyCut removeObject:oldSprite];
    }
    
    return sprCut;
}
//------------------------------------------------------------------------------
-(LHSprite*)createNewSpriteFromBodyInfo:(b2Body*)body 
                           andOldSprite:(LHSprite*)oldSprite
{
    b2Fixture* fixture = body->GetFixtureList();

    std::vector<CGPoint>triangles;
    
    while (fixture) {
        
        b2PolygonShape* poly = (b2PolygonShape*)fixture->GetShape();
        
        Vector2dVector result;
        Vector2dVector polygon;
        
        for(int k = 0; k < poly->GetVertexCount(); ++k){
            polygon.push_back(poly->m_vertices[k]);                
        }
        
        Triangulate::Process(polygon, result);
        
        for(int i = 0; i < (int)result.size()/3; ++i)
        {
            CGPoint texPoint[3];
            
            texPoint[0] = [LevelHelperLoader metersToPoints:result[i*3+0]];
            texPoint[1] = [LevelHelperLoader metersToPoints:result[i*3+1]];
            texPoint[2] = [LevelHelperLoader metersToPoints:result[i*3+2]];
            
            texPoint[0].x /= [oldSprite scaleX];
            texPoint[0].y /= [oldSprite scaleY];
            
            texPoint[1].x /= [oldSprite scaleX];
            texPoint[1].y /= [oldSprite scaleY];
            
            texPoint[2].x /= [oldSprite scaleX];
            texPoint[2].y /= [oldSprite scaleY];
            
            
            texPoint[0] = ccp(oldSprite.contentSize.width/2 - texPoint[0].x,
                              oldSprite.contentSize.height/2 - texPoint[0].y);
            
            texPoint[1] = ccp(oldSprite.contentSize.width/2 - texPoint[1].x,
                              oldSprite.contentSize.height/2 - texPoint[1].y);
            
            texPoint[2] = ccp(oldSprite.contentSize.width/2 - texPoint[2].x,
                              oldSprite.contentSize.height/2 - texPoint[2].y);
            
            
            triangles.push_back(texPoint[0]);
            triangles.push_back(texPoint[1]);
            triangles.push_back(texPoint[2]);
        }
        
        fixture = fixture->GetNext();
    }   
    
    CGPoint* texPoints = new CGPoint[triangles.size()];
    
    for(int i = 0; i < (int)triangles.size(); ++i){                                                            
        texPoints[i] = triangles[i];
    }
    
    LHSprite* newSprite = [self spriteWithVertices:texPoints
                                     verticesCount:(int)triangles.size()
                                         oldSprite:oldSprite];

    if(newSprite){
        [newSprite setFlipX:YES];
    }  
    
    delete[] texPoints;
    
    return newSprite;
}
//------------------------------------------------------------------------------
-(b2Body*)createBodyWithPoints:(b2Vec2*)verts 
                         count:(int)count 
                       oldBody:(b2Body*)oldBody
                    oldFixture:(b2Fixture*)oldFixture
{
    b2World* world = oldBody->GetWorld();
    
    if(world->IsLocked())
        NSLog(@"Box2d world is locked. Game will assert. Do not perform actions on a body when the Box2d world is locked. Trigger an action at the end of your tick method.");
    
    b2FixtureDef fixture;
    
    b2BodyDef bodyDef;	
    bodyDef.type = oldBody->GetType();        
    bodyDef.position = oldBody->GetPosition();
    bodyDef.angle = oldBody->GetAngle();
    b2Body* body = world->CreateBody(&bodyDef);
    
    bodyDef.fixedRotation = oldBody->IsFixedRotation();
    
    b2PolygonShape shape;
    
    shape.Set(verts, count);		
    
    fixture.density = oldFixture->GetDensity();
    fixture.friction =oldFixture->GetFriction();
    fixture.restitution = oldFixture->GetRestitution();
    fixture.filter = oldFixture->GetFilterData();
    
    fixture.isSensor = oldFixture->IsSensor();
    
    fixture.shape = &shape;
    body->CreateFixture(&fixture);
    
    //we use this define to figure out which version of Box2d the user has
    //its not nice that box2d does not have a compile time versioning just like cocos2d
#ifdef B2_EDGE_SHAPE_H 
    body->SetGravityScale(oldBody->GetGravityScale());
#endif
	body->SetSleepingAllowed(oldBody->IsSleepingAllowed());    
    body->SetBullet(oldBody->IsBullet());
    
    return body;
}
//------------------------------------------------------------------------------

-(LHSprite*)spriteWithVertices:(b2Vec2[])vertices 
                         count:(int)count
                     oldSprite:(LHSprite*)oldSprite
                       oldBody:(b2Body*)splitBody
                    oldFixture:(b2Fixture*)fixture
                 massDestroyer:(float)mass
{    
    b2Body* newBody = [self createBodyWithPoints:vertices 
                                           count:count 
                                         oldBody:splitBody
                                      oldFixture:fixture];
    
    if(newBody->GetMass() < mass)
    {
       b2World* world =  newBody->GetWorld();
        
        world->DestroyBody(newBody);
        return nil;
    }
    
    LHSprite* newSprite1 = [self createNewSpriteFromBodyInfo:newBody
                                                andOldSprite:oldSprite];
    
    if(newSprite1){
        
#ifndef LH_ARC_ENABLED
        newBody->SetUserData(newSprite1);
#else
        newBody->SetUserData((__bridge void*)newSprite1);
#endif

        [newSprite1 setBody:newBody];
    }
    
    return newSprite1;
}
//------------------------------------------------------------------------------
-(void) splitSprite:(LHSprite*)oldSprite atPoint:(CGPoint)location
{
    [self splitSprite:oldSprite 
              atPoint:location 
triangulateAllFixtures:NO
            ignoreSmallerMass:0];
}
//------------------------------------------------------------------------------
-(void) splitSprite:(LHSprite *)oldSprite 
                atPoint:(CGPoint)location 
 triangulateAllFixtures:(bool)breakFixturesOutsidePoint
      ignoreSmallerMass:(float)mass
{        
    b2Body* splitBody = [oldSprite body];

    if(splitBody == NULL)
        return;
    
    b2World* world = splitBody->GetWorld();

    b2Vec2 pointInBox2dCoord = [LevelHelperLoader pointsToMeters:location];
        
    b2Fixture* fixture = splitBody->GetFixtureList();
    
    while (fixture) {
        
        if(fixture->GetShape()->GetType() != b2Shape::e_polygon)
            return;
        
        b2PolygonShape* poly = (b2PolygonShape*)fixture->GetShape();
        
        if(fixture->TestPoint(pointInBox2dCoord))
        {
            b2Vec2 prevPoint = poly->GetVertex(0);
            
            for(int i = 1; i < poly->GetVertexCount(); ++i)
            {
                b2Vec2 point = poly->GetVertex(i);
                
                b2Vec2* vertices = new b2Vec2[3];
               
                vertices[0] = prevPoint;
                vertices[1] = point;
                vertices[2] = splitBody->GetLocalPoint(pointInBox2dCoord);
                
                [self spriteWithVertices:vertices
                                   count:3
                               oldSprite:oldSprite
                                 oldBody:splitBody
                              oldFixture:fixture
                           massDestroyer:mass];
                
                prevPoint = point;
                
                delete[] vertices;
            }
            
            b2Vec2* vertices = new b2Vec2[3];
            
            vertices[0] = poly->GetVertex(0);
            vertices[1] = poly->GetVertex(poly->GetVertexCount()-1);
            vertices[2] = splitBody->GetLocalPoint(pointInBox2dCoord);
                        
            
            [self spriteWithVertices:vertices
                               count:3
                           oldSprite:oldSprite
                             oldBody:splitBody
                          oldFixture:fixture
                       massDestroyer:mass];            

            delete[] vertices;
        }
        else {
                        
            Vector2dVector result;
            Vector2dVector polygon;
            
            for(int k = 0; k < poly->GetVertexCount(); ++k){
                polygon.push_back(poly->m_vertices[k]);                
            }
            
            Triangulate::Process(polygon, result);
            
            if(breakFixturesOutsidePoint)
            {
            for(size_t i = 0; i < result.size()/3; ++i)
            {
                b2Vec2* vertices = new b2Vec2[3];
                
                vertices[0] = result[i*3+0];
                vertices[1] = result[i*3+1];
                vertices[2] = result[i*3+2];
                      
                [self spriteWithVertices:vertices
                                   count:3
                               oldSprite:oldSprite
                                 oldBody:splitBody
                              oldFixture:fixture
                           massDestroyer:mass];
                
                delete[] vertices;
            }
            }
            else {
                
                [self spriteWithVertices:poly->m_vertices
                                   count:poly->GetVertexCount()
                               oldSprite:oldSprite
                                 oldBody:splitBody
                              oldFixture:fixture
                           massDestroyer:mass];                
            }
        }
        
        fixture = fixture->GetNext();
    }
    
    if([oldSprite isKindOfClass:[LHSprite class]]){
        [spritesPreviouslyCut removeObject:oldSprite];
        [(LHSprite*)oldSprite removeBodyFromWorld];//we force because of race condition
        [(LHSprite*)oldSprite removeSelf];
    }
    else{
        world->DestroyBody(splitBody);    
        [oldSprite removeFromParentAndCleanup:YES];
    }
}
//------------------------------------------------------------------------------

#define calculate_determinant_2x2(x1,y1,x2,y2) x1*y2-y1*x2
#define calculate_determinant_2x3(x1,y1,x2,y2,x3,y3) x1*y2+x2*y3+x3*y1-y1*x2-y2*x3-y3*x1
/*
 * Arranges all given points in a counter clockwise order
 */
-(b2Vec2*)makeVerticesCounterclockwise:(b2Vec2*)vertices count:(int)count
{
    float determinant;
    int iCounterClockWise = 1;
    int iClockWise = count - 1;
    int i;
    
    b2Vec2 referencePointA,referencePointB;
    b2Vec2 *sortedVertices = (b2Vec2*)calloc(count, sizeof(b2Vec2));
    
    // sort all vertices in ascending order according to their x-coordinate so we can get two points of a line
    qsort(vertices, count, sizeof(b2Vec2), comparator);
    
    sortedVertices[0] = vertices[0];
    referencePointA = vertices[0];          //leftmost point
    referencePointB = vertices[count-1];    //rightmost point
    
    // we arrange the points by filling our vertices in both clockwise and counter-clockwise directions using the determinant function
    for (i=1;i<count-1;i++)
    {
        determinant = calculate_determinant_2x3(referencePointA.x, referencePointA.y, referencePointB.x, referencePointB.y, vertices[i].x, vertices[i].y);
        if (determinant<0)
        {
            sortedVertices[iCounterClockWise++] = vertices[i];
        }
        else
        {
            sortedVertices[iClockWise--] = vertices[i];
        }//endif
    }//endif
    
    sortedVertices[iCounterClockWise] = vertices[count-1];
    return sortedVertices;
}

/*
 * Determines if a shape's vertices are acceptable by Box2D standards
 */
-(BOOL)areVerticesCompatibleWithBox2d:(b2Vec2*)vertices count:(int)count
{
    //check 1: polygons need to at least have 3 vertices
    if (count < 3){
        return NO;
    }
    
    //check 2: the number of vertices cannot exceed b2_maxPolygonVertices
    if (count > b2_maxPolygonVertices){
        return NO;
    }
    
    //check 3: Box2D needs the distance from each vertex to be greater than b2_epsilon
    int32 i;
    for (i=0; i<count; ++i){
        int32 i1 = i;
        int32 i2 = i + 1 < count ? i + 1 : 0;
        b2Vec2 edge = vertices[i2] - vertices[i1];
        if (edge.LengthSquared() <= b2_epsilon * b2_epsilon){
            return NO;
        }
    }
    
    //check 4: Box2D needs the area of a polygon to be greater than b2_epsilon
    float32 area = 0.0f;
    
    b2Vec2 pRef(0.0f,0.0f);
    
    for (i=0; i<count; ++i){
        b2Vec2 p1 = pRef;
        b2Vec2 p2 = vertices[i];
        b2Vec2 p3 = i + 1 < count ? vertices[i+1] : vertices[0];
        
        b2Vec2 e1 = p2 - p1;
        b2Vec2 e2 = p3 - p1;
        
        float32 D = b2Cross(e1, e2);
        
        float32 triangleArea = 0.5f * D;
        area += triangleArea;
    }
    
    //we assign a value of 0.0001 since anything further is too small to see anyway
    if (area <= 0.0001){
        return NO;
    }
    
    //check 5: Box2D requires that the shape be Convex.
    float determinant;
    float referenceDeterminant;
    b2Vec2 v1 = vertices[0] - vertices[count-1];
    b2Vec2 v2 = vertices[1] - vertices[0];
    referenceDeterminant = calculate_determinant_2x2(v1.x, v1.y, v2.x, v2.y);
    
    for (i=1; i<count-1; i++){
        v1 = v2;
        v2 = vertices[i+1] - vertices[i];
        determinant = calculate_determinant_2x2(v1.x, v1.y, v2.x, v2.y);
        //we use the determinant to check direction from one point to another. A convex shape's points should only go around in one direction. The sign of the determinant determines that direction. If the sign of the determinant changes mid-way, then we have a concave shape.
        if (referenceDeterminant * determinant < 0.0f){
            //if multiplying two determinants result to a negative value, we know that the sign of both numbers differ, hence it is concave
            return NO;
        }
    }
    //check the last two vertices
    v1 = v2;
    v2 = vertices[0]-vertices[count-1];
    determinant = calculate_determinant_2x2(v1.x, v1.y, v2.x, v2.y);
    if (referenceDeterminant * determinant < 0.0f){
        return NO;
    }
    //passed all tests
    return YES;
}






-(void)createFixtureWithVertices:(std::vector<b2Vec2>&)fixtureVertices
                          onBody:(b2Body*)body
                 fromOldFixture:(b2Fixture*)fixture
{
    int vsize = (int)fixtureVertices.size();
    b2Vec2 *verts = new b2Vec2[vsize];
    
    for(size_t i = 0; i<fixtureVertices.size(); ++i){
        verts[i].x = fixtureVertices[i].x;
        verts[i].y = fixtureVertices[i].y;
    }
    
    b2Vec2 *sortedVertices = [self makeVerticesCounterclockwise:verts count:vsize];
    if( [self areVerticesCompatibleWithBox2d:sortedVertices count:vsize])
    {
        b2PolygonShape shape;
        shape.Set(sortedVertices, vsize);
        b2FixtureDef fixtureDef;

        fixtureDef.density = fixture->GetDensity();
        fixtureDef.friction =fixture->GetFriction();
        fixtureDef.restitution = fixture->GetRestitution();
        fixtureDef.filter = fixture->GetFilterData();
        fixtureDef.isSensor = fixture->IsSensor();

        fixtureDef.shape = &shape;
        body->CreateFixture(&fixtureDef);
    }
    else {
        CCLOG(@"Centroid was not ok - dumped the fixture");
    }
    
    free(sortedVertices);
    delete[] verts;
}
//------------------------------------------------------------------------------
-(void)setInfoOnBody:(b2Body*)body fromBody:(b2Body*)splitBody
{
    if(!body || !splitBody)
        return;
    //we use this define to figure out which version of Box2d the user has
    //its not nice that box2d does not have a compile time versioning just like cocos2d
#ifdef B2_EDGE_SHAPE_H 
    body->SetGravityScale(splitBody->GetGravityScale());
#endif
    body->SetSleepingAllowed(splitBody->IsSleepingAllowed());    
    body->SetBullet(splitBody->IsBullet());
}
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
-(void) splitBody:(b2Body*)splitBody intersectionPointA:(b2Vec2)origA
                                        intersectionPointB:(b2Vec2)origB
                                                linePointA:(CGPoint)A
                                                linePointB:(CGPoint)B
{
    b2Fixture* fixture = splitBody->GetFixtureList();
    
#ifndef LH_ARC_ENABLED
    id oldSprite = (id)splitBody->GetUserData();
#else
    id oldSprite = (__bridge id)splitBody->GetUserData();
#endif
    
    if(![oldSprite isKindOfClass:[LHSprite class]])
        return;
    
    if([oldSprite imageFile] == nil)
        return;
    
//    if([(LHSprite*)oldSprite isTouchedAtPoint:A])
//    {
//        NSLog(@"We dont't cut old sprite because A is inside");
//        //if point is inside the sprite we need to cancel touch or else we will have noise
//        return;
//    }
//
//    if([(LHSprite*)oldSprite isTouchedAtPoint:B])
//    {
//        NSLog(@"We don't cut old sprite because B is inside");
//        //if point is inside the sprite we need to cancel touch or else we will have noise
//        return;
//    }
    
    b2World* world = splitBody->GetWorld();
    
    b2Vec2 pointA= splitBody->GetLocalPoint(origA);
    b2Vec2 pointB= splitBody->GetLocalPoint(origB);
    
    b2RayCastInput input1;
    input1.p1 = [LevelHelperLoader pointsToMeters:A];
    input1.p2 = [LevelHelperLoader pointsToMeters:B];
    input1.maxFraction = 1.0f;
    
    b2RayCastInput input2;
    input2.p1 = [LevelHelperLoader pointsToMeters:B];
    input2.p2 = [LevelHelperLoader pointsToMeters:A];
    input2.maxFraction = 1.0f;
    
    b2BodyDef bodyDef;	
    bodyDef.type = splitBody->GetType();        
    bodyDef.position = splitBody->GetPosition();
    bodyDef.angle = splitBody->GetAngle();
    bodyDef.fixedRotation = splitBody->IsFixedRotation();
    
    b2Body* body1 = world->CreateBody(&bodyDef);
    b2Body* body2 = world->CreateBody(&bodyDef);
    
    while (fixture) {
        
        int32 childIndex = 0;
        b2RayCastOutput output1;
        b2RayCastOutput output2;
        
        if(fixture->GetShape()->GetType() != b2Shape::e_polygon)
        {
            CCLOG(@"FIXTURE IS NOT POLYGON - CANCELING CUT");
            return;
        }
        
        b2PolygonShape* poly = (b2PolygonShape*)fixture->GetShape();
        
        //we use this define to figure out which version of Box2d the user has
        //its not nice that box2d does not have a compile time versioning just like cocos2d
#ifdef B2_EDGE_SHAPE_H 
        bool hit1 = poly->RayCast(&output1, input1,splitBody->GetTransform(), childIndex);
#else
        bool hit1 = poly->RayCast(&output1, input1, splitBody->GetTransform());
#endif
        b2Vec2 hitPoint1;
        
        if(hit1){
            hitPoint1 = input1.p1 + output1.fraction * (input1.p2 - input1.p1);            
        }
        //we use this define to figure out which version of Box2d the user has
        //its not nice that box2d does not have a compile time versioning just like cocos2d
#ifdef B2_EDGE_SHAPE_H 
        bool hit2 = poly->RayCast(&output2, input2,splitBody->GetTransform(), childIndex);
#else 
        bool hit2 = poly->RayCast(&output2, input2,splitBody->GetTransform());
#endif
        b2Vec2 hitPoint2;
        if(hit2){
            hitPoint2 = input2.p1 + output2.fraction * (input2.p2 - input2.p1);            
        }
        
        if(hit1 && hit2)
        {
            std::vector<b2Vec2>shape1Vertices;
            std::vector<b2Vec2>shape2Vertices;
            
            shape1Vertices.push_back(splitBody->GetLocalPoint(hitPoint1));            
            shape2Vertices.push_back(splitBody->GetLocalPoint(hitPoint1));
            
            //if we have 2 hits we can split the fixture - else we leave it as it is            
            for(int i = 0; i< poly->GetVertexCount(); ++i){                
                bool d = isLeft(pointA, pointB, poly->GetVertex(i));
                
                if(d){
                    shape1Vertices.push_back(poly->GetVertex(i));
                }
                else {
                    shape2Vertices.push_back(poly->GetVertex(i));
                }
			}
            
            if(shape1Vertices.size() < b2_maxPolygonVertices){
                shape1Vertices.push_back(splitBody->GetLocalPoint(hitPoint2));
            }
            
            if(shape2Vertices.size() < b2_maxPolygonVertices){
                shape2Vertices.push_back(splitBody->GetLocalPoint(hitPoint2));
            }
            
            if(shape1Vertices.size() >= 3 && shape1Vertices.size() <= b2_maxPolygonVertices)
            {
                [self createFixtureWithVertices:shape1Vertices
                                         onBody:body1
                                 fromOldFixture:fixture];                
            }
            else {
               // NSLog(@"MORE POINTS IN SHAPE 1 %d", shape1Vertices.size());
            }
            
            if(shape2Vertices.size() >= 3 && shape2Vertices.size() <= b2_maxPolygonVertices)
            {
                [self createFixtureWithVertices:shape2Vertices
                                         onBody:body2
                                 fromOldFixture:fixture];
            }
            else {
              //  NSLog(@"MORE POINTS IN SHAPE 2 %d", shape2Vertices.size());
            }
            
        }
        else {
            //I JUST NEED TO CREATE THE FIXTURE AND PUT IT IN THE APPROPRIATE BODY

            std::vector<b2Vec2>shape1Vertices;
            std::vector<b2Vec2>shape2Vertices;
            
            b2PolygonShape* poly = (b2PolygonShape*)fixture->GetShape();
            
            for(int i = 0; i< poly->GetVertexCount(); ++i){
                bool d = isLeft(pointA, pointB, poly->GetVertex(i));
                
                if(d){
                    shape1Vertices.push_back(poly->GetVertex(i));
                }
                else {
                    shape2Vertices.push_back(poly->GetVertex(i));
                }
			}
            
            if(shape1Vertices.size() >= 3 && shape1Vertices.size() <= b2_maxPolygonVertices)
            {
                [self createFixtureWithVertices:shape1Vertices
                                         onBody:body1
                                 fromOldFixture:fixture];
            }
            else {
               // NSLog(@"MORE POINTS IN SHAPE 1b %d", shape1Vertices.size());
            }
            
            if(shape2Vertices.size() >= 3 && shape2Vertices.size() <= b2_maxPolygonVertices)
            {
                [self createFixtureWithVertices:shape2Vertices
                                         onBody:body2
                                 fromOldFixture:fixture];
            }
            else {
              //  NSLog(@"MORE POINTS IN SHAPE 2b %d", shape2Vertices.size());
            }
            
        }
        
        fixture = fixture->GetNext();
    }
    
    if(body1 != NULL)
    {
    if (body1->GetFixtureList() != NULL) //we have no fixture in this body - lets dump it
    {
        LHSprite* newSprite1 = [self createNewSpriteFromBodyInfo:body1 andOldSprite:oldSprite];
    
        if(newSprite1){
#ifndef LH_ARC_ENABLED
            body1->SetUserData(newSprite1);
#else
            body1->SetUserData((__bridge void*)newSprite1);
#endif

            [newSprite1 setBody:body1];
        }
    }
    else {
        world->DestroyBody(body1);
        body1 = NULL;
    }
    }
    
    if(body2 != NULL)
    {
    if(body2->GetFixtureList() != NULL)
    {
        LHSprite* newSprite2 = [self createNewSpriteFromBodyInfo:body2 andOldSprite:oldSprite];
    
        if(newSprite2){
#ifndef LH_ARC_ENABLED
            body2->SetUserData(newSprite2);
#else
            body2->SetUserData((__bridge void*)newSprite2);
#endif

            [newSprite2 setBody:body2];
        } 
    }
    else {
        world->DestroyBody(body2);
        body2 = NULL;
    }
    }
    
    if(body1)
        [self setInfoOnBody:body1 fromBody:splitBody];
    if(body2)
        [self setInfoOnBody:body2 fromBody:splitBody];
    
    if([oldSprite isKindOfClass:[LHSprite class]]){
        [spritesPreviouslyCut removeObject:oldSprite];
        [(LHSprite*)oldSprite removeBodyFromWorld];//we force because of race condition
        [(LHSprite*)oldSprite removeSelf];
    }
    else{
        world->DestroyBody(splitBody);    
        [LevelHelperLoader removeTouchDispatcherFromObject:oldSprite];
        [oldSprite removeFromParentAndCleanup:YES];
    }
        
    return;
}
//------------------------------------------------------------------------------
+(float) distanceBetweenPoint:(b2Vec2)point1 andPoint:(b2Vec2)point2{
    float xd = point1.x - point2.x;
    float yd = point1.y - point2.y;
    return sqrtf(xd*xd + yd*yd);
}
//------------------------------------------------------------------------------
-(void)cutFirstSpriteIntersectedByLine:(CGPoint)startPt 
                                     lineB:(CGPoint)endPt
                                 fromWorld:(b2World*)world
{
    
    b2Vec2 p1 = [LevelHelperLoader pointsToMeters:startPt];
	b2Vec2 p2 = [LevelHelperLoader pointsToMeters:endPt];
	b2Vec2 r = p2 - p1;
	if(r.LengthSquared() <= 0.0f){
        return;
    }
    
    AllBodiesRayCastCallback callback1;
    world->RayCast(&callback1, 
                   p1,
                   p2);
    
    AllBodiesRayCastCallback callback2;
    world->RayCast(&callback2, 
                   p2,
                   p1);
    
    float distance = 0.0f;
    b2Body* bodyToCut = NULL;
    b2Vec2 pointAOnBody;
    b2Vec2 pointBOnBody;
    
    std::map<b2Body*, b2Vec2>::iterator it;
    for(it = callback1.rayCastInfo.begin(); it != callback1.rayCastInfo.end(); ++it)
    {
        b2Body* key = (*it).first;    
        std::map<b2Body*, b2Vec2>::iterator it2 = callback2.rayCastInfo.find(key);
        if(it2 != callback2.rayCastInfo.end())
        {
            float dist = [LHCuttingEngineMgr distanceBetweenPoint:key->GetPosition() 
                                                         andPoint:p1];
            
            if(bodyToCut == NULL)
            {
                distance = dist;
                bodyToCut = key;
                pointAOnBody = (*it).second;
                pointBOnBody = (*it2).second;
            }
            else {
                
                if(dist < distance)
                {                 
                    distance = dist;
                    bodyToCut = key;
                    pointAOnBody = (*it).second;
                    pointBOnBody = (*it2).second;
                }
            }            
        }
    }

    if(bodyToCut)
    {
        [self splitBody:bodyToCut
            intersectionPointA:pointAOnBody
            intersectionPointB:pointBOnBody
                        linePointA:startPt
                        linePointB:endPt];
    }
}
//------------------------------------------------------------------------------
-(void)cutFirstSpriteWithTag:(int)tag
           intersectedByLine:(CGPoint)startPt 
                       lineB:(CGPoint)endPt
                   fromWorld:(b2World*)world
{
    
    b2Vec2 p1 = [LevelHelperLoader pointsToMeters:startPt];
	b2Vec2 p2 = [LevelHelperLoader pointsToMeters:endPt];
	b2Vec2 r = p2 - p1;
	if(r.LengthSquared() <= 0.0f){
        return;
    }
        
    AllBodiesRayCastCallback callback1;
    world->RayCast(&callback1, 
                   p1,
                   p2);
    
    AllBodiesRayCastCallback callback2;
    world->RayCast(&callback2, 
                   p2,
                   p1);
    
    float distance = 0.0f;
    b2Body* bodyToCut = NULL;
    b2Vec2 pointAOnBody;
    b2Vec2 pointBOnBody;
    
    std::map<b2Body*, b2Vec2>::iterator it;
    for(it = callback1.rayCastInfo.begin(); it != callback1.rayCastInfo.end(); ++it)
    {
        b2Body* key = (*it).first;    
        
        
#ifndef LH_ARC_ENABLED
        LHSprite* sprite = (LHSprite*)key->GetUserData();
#else
        LHSprite* sprite = (__bridge LHSprite*)key->GetUserData();
#endif
        
        
        
        if(sprite && [sprite tag] == tag)
        {
            std::map<b2Body*, b2Vec2>::iterator it2 = callback2.rayCastInfo.find(key);
            if(it2 != callback2.rayCastInfo.end())
            {
                float dist = [LHCuttingEngineMgr distanceBetweenPoint:key->GetPosition() 
                                                             andPoint:p1];
                
                if(bodyToCut == NULL)
                {
                    distance = dist;
                    bodyToCut = key;
                    pointAOnBody = (*it).second;
                    pointBOnBody = (*it2).second;
                }
                else {
                
                    if(dist < distance)
                    {                 
                        distance = dist;
                        bodyToCut = key;
                        pointAOnBody = (*it).second;
                        pointBOnBody = (*it2).second;
                    }
                }            
            }
        }
    }
    
    if(bodyToCut)
    {
#ifndef LH_ARC_ENABLED
        LHSprite* sprite = (LHSprite*)bodyToCut->GetUserData();
#else
        LHSprite* sprite = (__bridge LHSprite*)bodyToCut->GetUserData();
#endif

        if (sprite && [sprite tag] == tag) {
            [self splitBody:bodyToCut 
                    intersectionPointA:pointAOnBody
                    intersectionPointB:pointBOnBody
                    linePointA:startPt
                    linePointB:endPt];
        }
    }
}
//------------------------------------------------------------------------------
-(void)cutSprite:(LHSprite*)oldSprite
       withLineA:(CGPoint)startPt
           lineB:(CGPoint)endPt
{
    
    b2Vec2 p1 = [LevelHelperLoader pointsToMeters:startPt];
	b2Vec2 p2 = [LevelHelperLoader pointsToMeters:endPt];
	b2Vec2 r = p2 - p1;
	if(r.LengthSquared() <= 0.0f)
    {
        return;
    }
    
    b2Body* oldBody = [oldSprite body];
    
    if(oldBody == NULL)
        return;
    
    b2World* world = oldBody->GetWorld();
    
    AllBodiesRayCastCallback callback1;
    world->RayCast(&callback1, 
                   p1,
                   p2);
    
    AllBodiesRayCastCallback callback2;
    world->RayCast(&callback2, 
                   p2,
                   p1);
    
    std::map<b2Body*, b2Vec2>::iterator it;
    for(it = callback1.rayCastInfo.begin(); it != callback1.rayCastInfo.end(); ++it)
    {
        b2Body* key = (*it).first;    
        std::map<b2Body*, b2Vec2>::iterator it2 = callback2.rayCastInfo.find(key);
        if(it2 != callback2.rayCastInfo.end())
        {
            b2Vec2 pointA = (*it).second;
            b2Vec2 pointB = (*it2).second;
            
#ifndef LH_ARC_ENABLED
            LHSprite* sprite = (LHSprite*)key->GetUserData();
#else
            LHSprite* sprite = (__bridge LHSprite*)key->GetUserData();
#endif

            if(oldSprite == sprite)
            {
                [self splitBody:key 
             intersectionPointA:pointA
             intersectionPointB:pointB
                     linePointA:startPt
                     linePointB:endPt];
            
            }
        }
    }
}
//------------------------------------------------------------------------------
-(void)cutAllSpritesIntersectedByLine:(CGPoint)startPt
                                    lineB:(CGPoint)endPt
                                fromWorld:(b2World*)world
{
    b2Vec2 p1 = [LevelHelperLoader pointsToMeters:startPt];
	b2Vec2 p2 = [LevelHelperLoader pointsToMeters:endPt];
	b2Vec2 r = p2 - p1;
	if(r.LengthSquared() <= 0.0f)
    {
        return;
    }
    
    AllBodiesRayCastCallback callback1;
    world->RayCast(&callback1, 
                   p1,
                   p2);
    
    AllBodiesRayCastCallback callback2;
    world->RayCast(&callback2, 
                   p2,
                   p1);
    
    std::map<b2Body*, b2Vec2>::iterator it;
    for(it = callback1.rayCastInfo.begin(); it != callback1.rayCastInfo.end(); ++it)
    {
        b2Body* key = (*it).first;    
        std::map<b2Body*, b2Vec2>::iterator it2 = callback2.rayCastInfo.find(key);
        if(it2 != callback2.rayCastInfo.end())
        {
            b2Vec2 pointA = (*it).second;
            b2Vec2 pointB = (*it2).second;
            
            [self splitBody:key 
         intersectionPointA:pointA
         intersectionPointB:pointB
                 linePointA:startPt
                 linePointB:endPt];
            
        }
    }
}
//------------------------------------------------------------------------------
-(void)cutAllSpritesWithTag:(int)tag
             intersectedByLine:(CGPoint)startPt
                         lineB:(CGPoint)endPt
                     fromWorld:(b2World*)world{

    AllBodiesRayCastCallback callback1;
    world->RayCast(&callback1, 
                   [LevelHelperLoader pointsToMeters:startPt] , 
                   [LevelHelperLoader pointsToMeters:endPt]);
    
    AllBodiesRayCastCallback callback2;
    world->RayCast(&callback2, 
                   [LevelHelperLoader pointsToMeters:endPt] , 
                   [LevelHelperLoader pointsToMeters:startPt]);
    
    std::map<b2Body*, b2Vec2>::iterator it;
    for(it = callback1.rayCastInfo.begin(); it != callback1.rayCastInfo.end(); it++)
    {
        b2Body* key = (*it).first;    
        
        std::map<b2Body*, b2Vec2>::iterator it2 = callback2.rayCastInfo.find(key);
        if(it2 != callback2.rayCastInfo.end())
        {
            b2Vec2 pointA = (*it).second;
            b2Vec2 pointB = (*it2).second;
        
#ifndef LH_ARC_ENABLED
            LHSprite* sprite = (LHSprite*)key->GetUserData();
#else
            LHSprite* sprite = (__bridge LHSprite*)key->GetUserData();
#endif
            
            if(sprite && [sprite tag] == tag)
            {
                [self splitBody:key 
                   intersectionPointA:pointA
                   intersectionPointB:pointB
                           linePointA:startPt
                           linePointB:endPt];                
            }            
        }
    }
}
//------------------------------------------------------------------------------
- (float)randomFloatBetween:(float)smallNumber andBig:(float)bigNumber {
    float diff = bigNumber - smallNumber;
    return (((float) (arc4random() % ((unsigned)RAND_MAX + 1)) / RAND_MAX) * diff) + smallNumber;
}
//------------------------------------------------------------------------------
-(void) createExplosionWithCuts:(int)numberOfCuts 
                         radius:(float)radius
                        atPoint:(CGPoint)explosionPoint
{    
    explosionLines.clear();    
    for(int i = 0; i < numberOfCuts/2; ++i)
    {
        float cutAngle = [self randomFloatBetween:0 andBig:360];
                
        float x = explosionPoint.x + radius * cos (cutAngle);
        float y = explosionPoint.y + radius * sin (cutAngle);
        
        float x1 = explosionPoint.x - radius * cos (cutAngle);
        float y1 = explosionPoint.y - radius * sin (cutAngle);
        
        explosionLines.push_back(CGPointMake(x, y));
        explosionLines.push_back(CGPointMake(x1, y1));
    }
}
//------------------------------------------------------------------------------
-(void)cutSpritesFromPoint:(CGPoint)point
                     inRadius:(float)radius
                          cuts:(int)numberOfCuts
                     fromWorld:(b2World*)world
{
    [self createExplosionWithCuts:numberOfCuts
                           radius:radius
                          atPoint:point];
    
    for(size_t i = 0; i< explosionLines.size()/2; i +=2)
    {
        CGPoint lineA = explosionLines[i*2+0];
        CGPoint lineB = explosionLines[i*2+1];
        [self cutAllSpritesIntersectedByLine:lineA
                                       lineB:lineB
                                   fromWorld:world];
    }
}
//------------------------------------------------------------------------------
-(void)cutSpritesWithTag:(int)tag
               fromPoint:(CGPoint)point
                inRadius:(float)radius
                    cuts:(int)numberOfCuts
               fromWorld:(b2World*)world
{
    [self createExplosionWithCuts:numberOfCuts
                           radius:radius
                          atPoint:point];
    
    for(size_t i = 0; i< explosionLines.size()/2; i +=2)
    {
        CGPoint lineA = explosionLines[i*2+0];
        CGPoint lineB = explosionLines[i*2+1];
        [self cutAllSpritesWithTag:tag
                 intersectedByLine:lineA
                             lineB:lineB
                         fromWorld:world];        
    }
}

-(void) explodeSpritesInRadius:(float)radius
                     withForce:(float)maxForce
                      position:(CGPoint)pos
                       inWorld:(b2World*)world
{
    [self explodeSpritesInRadius:radius withForce:maxForce position:pos inWorld:world suction:NO];
}

-(void) implodeSpritesInRadius:(float)radius
                     withForce:(float)maxForce
                      position:(CGPoint)pos
                       inWorld:(b2World*)world
{
    [self explodeSpritesInRadius:radius withForce:maxForce position:pos inWorld:world suction:YES];
}

//------------------------------------------------------------------------------
-(bool)cutRopeJoint:(LHJoint*)joint
 withLineFromPointA:(CGPoint)ptA
           toPointB:(CGPoint)ptB{
    
    if(joint == nil)return false;
    if([joint type] != LH_ROPE_JOINT)return false;
    
    return [joint cutRopeJointsIntesectingWithLineFromPointA:ptA
                                                    toPointB:ptB];
}

-(void)cutRopeJoints:(NSArray*)jointsArray
  withLineFromPointA:(CGPoint)ptA
            toPointB:(CGPoint)ptB{

    for(LHJoint* joint in jointsArray){
        if(joint == nil)return;
        if([joint type] != LH_ROPE_JOINT)return;
    
        [joint cutRopeJointsIntesectingWithLineFromPointA:ptA
                                                 toPointB:ptB];
    }
}



-(void)debugDrawing{
    
    for(size_t i = 0; i < explosionLines.size(); i+=2)
    {
#if COCOS2D_VERSION >= 0x00020000 
        
        //XXX - GLES 2.0 draw call here
#else
        
        glDisable(GL_TEXTURE_2D);		
        glColor4f(1, 0, 0, 1);
        CGPoint vertices[2];
        
        vertices[0] = explosionLines[i];
        vertices[1] = explosionLines[i+1];
        
        glVertexPointer(2, GL_FLOAT, 0, &vertices);
        glDrawArrays(GL_LINES, 0, 2);
#endif
    }
}

@end
#endif