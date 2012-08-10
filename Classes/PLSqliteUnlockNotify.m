/*
 * Copyright (c) 2011 Plausible Labs Cooperative, Inc.
 * All rights reserved.
 *
 * This code is directly derived from the public domain example code available from:
 * http://www.sqlite.org/unlock_notify.html
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. Neither the name of the copyright holder nor the names of any contributors
 *    may be used to endorse or promote products derived from this
 *    software without specific prior written permission.
 * 
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

#import "PLSqliteUnlockNotify.h"

#import <pthread.h>

/*
 * A pointer to an instance of this structure is passed as the user-context
 * pointer when registering for an unlock-notify callback.
 */
typedef struct UnlockNotification UnlockNotification;
struct UnlockNotification {
    int fired;                           /* True after unlock event has occured */
    pthread_cond_t cond;                 /* Condition variable to wait on */
    pthread_mutex_t mutex;               /* Mutex to protect structure */
};

/*
 * This function is an unlock-notify callback registered with SQLite.
 */
static void unlock_notify_cb(void **apArg, int nArg){
    int i;
    for(i=0; i<nArg; i++){
        UnlockNotification *p = (UnlockNotification *)apArg[i];
        pthread_mutex_lock(&p->mutex);
        p->fired = 1;
        pthread_cond_signal(&p->cond);
        pthread_mutex_unlock(&p->mutex);
    }
}

/*
 * This function assumes that an SQLite API call (either sqlite3_prepare_v2() 
 * or sqlite3_step()) has just returned SQLITE_LOCKED. The argument is the
 * associated database connection.
 *
 * This function calls sqlite3_unlock_notify() to register for an 
 * unlock-notify callback, then blocks until that callback is delivered 
 * and returns SQLITE_OK. The caller should then retry the failed operation.
 *
 * Or, if sqlite3_unlock_notify() indicates that to block would deadlock 
 * the system, then this function returns SQLITE_LOCKED immediately. In 
 * this case the caller should not retry the operation and should roll 
 * back the current transaction (if any).
 */
static int wait_for_unlock_notify(sqlite3 *db){
    int rc;
    UnlockNotification un;
    
    /* Initialize the UnlockNotification structure. */
    un.fired = 0;
    pthread_mutex_init(&un.mutex, 0);
    pthread_cond_init(&un.cond, 0);
    
    /* Register for an unlock-notify callback. */
    rc = sqlite3_unlock_notify(db, unlock_notify_cb, (void *)&un);
    assert( rc==SQLITE_LOCKED || rc==SQLITE_OK );
    
    /* The call to sqlite3_unlock_notify() always returns either SQLITE_LOCKED 
     ** or SQLITE_OK. 
     **
     ** If SQLITE_LOCKED was returned, then the system is deadlocked. In this
     ** case this function needs to return SQLITE_LOCKED to the caller so 
     ** that the current transaction can be rolled back. Otherwise, block
     ** until the unlock-notify callback is invoked, then return SQLITE_OK.
     */
    if( rc==SQLITE_OK ){
        pthread_mutex_lock(&un.mutex);
        if( !un.fired ){
            pthread_cond_wait(&un.cond, &un.mutex);
        }
        pthread_mutex_unlock(&un.mutex);
    }
    
    /* Destroy the mutex and condition variables. */
    pthread_cond_destroy(&un.cond);
    pthread_mutex_destroy(&un.mutex);
    
    return rc;
}

/*
 ** This function is a wrapper around the SQLite function sqlite3_step().
 ** It functions in the same way as step(), except that if a required
 ** shared-cache lock cannot be obtained, this function may block waiting for
 ** the lock to become available. In this scenario the normal API step()
 ** function always returns SQLITE_LOCKED.
 **
 ** If this function returns SQLITE_LOCKED, the caller should rollback
 ** the current transaction (if any) and try again later. Otherwise, the
 ** system may become deadlocked.
 */
int pl_sqlite3_blocking_step(sqlite3_stmt *pStmt){
    int rc;
    while( SQLITE_LOCKED==(rc = sqlite3_step(pStmt)) ){
        rc = wait_for_unlock_notify(sqlite3_db_handle(pStmt));
        if( rc!=SQLITE_OK ) break;
        sqlite3_reset(pStmt);
    }
    return rc;
}

/*
 ** This function is a wrapper around the SQLite function sqlite3_prepare_v2().
 ** It functions in the same way as prepare_v2(), except that if a required
 ** shared-cache lock cannot be obtained, this function may block waiting for
 ** the lock to become available. In this scenario the normal API prepare_v2()
 ** function always returns SQLITE_LOCKED.
 **
 ** If this function returns SQLITE_LOCKED, the caller should rollback
 ** the current transaction (if any) and try again later. Otherwise, the
 ** system may become deadlocked.
 */
int pl_sqlite3_blocking_prepare_v2(
                                sqlite3 *db,              /* Database handle. */
                                const char *zSql,         /* UTF-8 encoded SQL statement. */
                                int nSql,                 /* Length of zSql in bytes. */
                                sqlite3_stmt **ppStmt,    /* OUT: A pointer to the prepared statement */
                                const char **pz           /* OUT: End of parsed string */
                                ){
    int rc;
    while( SQLITE_LOCKED==(rc = sqlite3_prepare_v2(db, zSql, nSql, ppStmt, pz)) ){
        rc = wait_for_unlock_notify(db);
        if( rc!=SQLITE_OK ) break;
    }
    return rc;
}