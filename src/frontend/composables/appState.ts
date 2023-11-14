import { Effect, pipe } from "effect";
import { FrontendEffect, Question, User } from "~/helper/backend";
import { FrontendError, notifyWithMsg } from "~/helper/errors";
import { defineStore } from 'pinia'

export type AppState = {
    user: NetworkData<User>,
    openQuestions: NetworkData<Question[]>,
};

type NotificationLevel = "ok" | "warning" | "error";

type DataStatus = "init" | "requested" | "error" | "ok";
export type NetworkData<T> = {
    status: DataStatus;
    data?: T;
    lastOK?: Date;
    err?: FrontendError;
    lastErr?: Date;
};
const dataInit: NetworkData<any> = {
    status: "init",
    data: undefined,
    lastOK: undefined,
    err: undefined,
    lastErr: undefined,
}


type FrontendEffectToEffect<A> = (effect: FrontendEffect<A>) => FrontendEffect<A>;

const setRequested = <A>(): NetworkData<A> => {
    return {
        status: "requested",
        data: undefined,
    };
}

const setOk = <A>(data: A): NetworkData<A> => {
    console.log("qwer", data)
    return {
        status: "ok",
        data,
        lastOK: new Date(),
    }
}

const setErr = <A>(err: FrontendError): NetworkData<A> => {
    return {
        status: "error",
        err,
        lastErr: new Date(),
    }
}

export const storeToData = <A>(effect: FrontendEffect<A>, store: (a: NetworkData<A>) => void): FrontendEffect<A> => {
    const before = Effect.sync<void>(() => {
        console.log("requesting")
        store(setOk(undefined as A));
        setTimeout(() => store(setRequested()));
    })
    const after = Effect.mapBoth<FrontendError, A, FrontendError, A>({
        onSuccess: (a) => {
            console.log("request ok")
            store(setOk(undefined as A));
            setTimeout(() => store(setOk(a)));
            return a;
        },
        onFailure: (e) => {
            console.log("request error")
            store(setErr(e))
            return e;
        },
    })
    return pipe(
        before,
        () => effect,
        after
    )
}


export const runStoreNotify = <A>(effect: FrontendEffect<A>, store: (a: NetworkData<A>) => void, msg?: string): Promise<A> => {
    return Effect.runPromise(
        storeToData(
            effect.pipe(notifyWithMsg(msg)),
            store,
        )
    );
}

export const runNotify = <A>(effect: FrontendEffect<A>, msg?: string): Promise<A> => {
    return runStoreNotify(effect, (_) => { }, msg);
}

const combineNetworkData = <A>(old: NetworkData<A>, newer: NetworkData<A>): NetworkData<A> => {
    switch (newer.status) {
        case "ok": return newer;
        case "error":
        case "requested": return { ...newer, data: old.data, lastOK: old.lastOK };
        case "init": throw "combineNetworkData should never be called with init as new value"
    }
}


const defaultAppState: AppState = {
    user: dataInit,
    openQuestions: dataInit,
};

export const useAppState = defineStore('app', {
    state: () => defaultAppState,
    actions: {
        setOpenQuestions(qs: NetworkData<Question[]>) {
            this.openQuestions = combineNetworkData(this.openQuestions, qs);
        },
        setUser(user: NetworkData<User>) {
            this.user = combineNetworkData(this.user, user)
        }
    }
});

export const addNotification = (level: NotificationLevel, msg: string): void => {
    if (!process.client) {
        switch (level) {
            case "ok": console.log("notification (" + level + "): " + msg); break;
            case "warning": console.warn("notification (" + level + "): " + msg); break;
            case "error": console.error("notification (" + level + "): " + msg); break;
        }
        return;
    }
    const toast = useNuxtApp().$toast;
    switch (level) {
        case "ok": toast.success(msg, { autoClose: 1000 }); break;
        case "warning": toast.warning(msg); break;
        case "error": toast.error(msg); break;
    }
}
