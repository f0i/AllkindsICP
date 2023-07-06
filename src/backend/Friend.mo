import Principal "mo:base/Principal";
import Map "mo:map/Map";
import Result "mo:base/Result";
import Option "mo:base/Option";
import Error "Error";
import Iter "mo:base/Iter";
import IterTools "mo:itertools/Iter";
import Debug "mo:base/Debug";

module {

  type Map<K, V> = Map.Map<K, V>;
  type Result<K, V> = Result.Result<K, V>;
  type Error = Error.Error;
  type Iter<T> = Iter.Iter<T>;

  public type FriendDB = Map<Principal, UserFriends>;
  type UserFriends = Map<Principal, FriendStatus>;

  let { phash } = Map;

  public func emptyDB() : FriendDB = Map.new<Principal, UserFriends>(phash);

  public type FriendStatus = {
    #requestSend;
    #requestReceived;
    #connected;
    #requestIgnored;
    #rejectionSend;
    #rejectionReceived;
  };

  public func backup(friends : FriendDB) : Iter<(Principal, Principal, FriendStatus)> {
    let usersA = Map.entries(friends);
    let ?(a, userFriends) = usersA.next() else return IterTools.empty();
    var userA = a;
    var userFriendsIter = Map.entries(userFriends);

    func next() : ?(Principal, Principal, FriendStatus) {
      switch (userFriendsIter.next()) {
        case (?(userB, status)) {
          return ?(userA, userB, status);
        };
        case (null) {
          // iterator userFriendsIter is used up -> get iterator for next one
          let ?(a, userFriends) = usersA.next() else return null;
          userFriendsIter := Map.entries(userFriends);
          next();
        };
      };
    };

    return { next };
  };

  public func request(friends : FriendDB, sender : Principal, recipient : Principal) : Result<(), Error> {
    let senderFriends = getFriends(friends, sender);
    let recipientFriends = getFriends(friends, recipient);
    if (sender == recipient) return #err(#friendAlreadyConnected);

    let senderStatus = getFriend(senderFriends, recipient);
    let recipientStatus = getFriend(recipientFriends, sender);

    switch ((senderStatus, recipientStatus)) {
      case (null, null) {
        // send a new request
        Map.set(senderFriends, phash, recipient, #requestSend);
        Map.set(recipientFriends, phash, sender, #requestReceived);
      };
      case (?(#requestReceived), ?(#requestSend)) {
        // other user already requested
        Map.set(senderFriends, phash, recipient, #connected);
        Map.set(recipientFriends, phash, sender, #connected);
      };
      case (?(#connected), ?(#connected)) {
        // already connected
        return #ok;
      };
      case (_, _) {
        return #err(#friendRequestAlreadySend);
      };
    };
    Map.set(friends, phash, sender, senderFriends);
    Map.set(friends, phash, recipient, recipientFriends);

    #ok;
  };

  public func reject(friends : FriendDB, sender : Principal, recipient : Principal) : Result<(), Error> {
    if (Principal.isAnonymous(sender)) { return #err(#notLoggedIn) };
    if (Principal.isAnonymous(recipient)) { return #err(#userNotFound) };
    if (sender == recipient) return #err(#friendAlreadyConnected);

    let senderFriends = getFriends(friends, sender);
    let recipientFriends = getFriends(friends, sender);

    let senderStatus = getFriend(senderFriends, recipient);
    let recipientStatus = getFriend(recipientFriends, sender);

    switch (recipientStatus) {
      case (?(#requestIgnored)) {
        // other user already requested
        Map.set(senderFriends, phash, recipient, #rejectionSend);
        Map.set(recipientFriends, phash, sender, #requestIgnored);
      };
      case (?(#rejectionSend)) {
        // other user already requested
        Map.set(senderFriends, phash, recipient, #rejectionSend);
        Map.set(recipientFriends, phash, sender, #rejectionSend);
      };
      case (_) {
        // send a new request
        Map.set(senderFriends, phash, recipient, #rejectionSend);
        Map.set(recipientFriends, phash, sender, #rejectionReceived);
      };
    };

    Map.set(friends, phash, sender, senderFriends);
    Map.set(friends, phash, recipient, recipientFriends);

    #ok;
  };

  public func get(friends : FriendDB, user : Principal) : Iter<(Principal, FriendStatus)> {
    Map.entries(getFriends(friends, user));
  };

  /// Check if userA has any friend status set with userB (including rejected and pending requests)
  public func has(friends : FriendDB, userA : Principal, userB : Principal) : Bool {
    Map.has(getFriends(friends, userA), phash, userB);
  };

  // Get map of friend status or create an empty map
  func getFriends(friends : FriendDB, user : Principal) : UserFriends {
    Option.get(
      Map.get(friends, phash, user),
      Map.new<Principal, FriendStatus>(phash),
    );
  };

  func getFriend(friends : UserFriends, user : Principal) : ?FriendStatus {
    Map.get(friends, phash, user);
  };

};