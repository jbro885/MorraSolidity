pragma solidity >=0.4.22 <0.6.0;
/**
 * An ethereum contract for a Morra game between two people
 * Address: 0xa7dd711CDD846039A9D14A5643b936346BC8E2c7
 */
contract Morra {
    struct guess {
        //the address of the commited player
        address player;
        // the number chosen for themself, after revealing.
        uint8 myNumber;
        // the hash of the number chosen for themself, after revealing, in the form of a hashed string that ends with the desired number
        bytes32 hashMyNumber;
        // the number guessed for the other player's value, after revealing
        uint8 guessedNumber;
        // the hash of the number guessed, after revealing, in the form of a hashed string that ends with the desired number
        bytes32 hashGuessedNumber;
    }
    // how much is owed to each player
    mapping (address => uint256) refunds;
    // records (up to) two game entries for each round
    guess[] public guesses;
    // value of guess.myNumber and guessedNumber before revealing
    uint8 private constant NOT_RVLD = 6;
    // how much ether is needed to play a round
    uint256 public constant gamePrice = 5 * gamePriceUnit;
    uint256 private constant gamePriceUnit = 1 ether;
    // stores the time both players committed for this round. Used to avoid non revealing players stalling the game
    uint256 private timeOfGame = 0;
    // this is how long a round lasts before it expires and can be terminated manually
    int256 public constant maxTimeTillGameExpiry = 1 days;
    // notifies the players that there is a reward for them that can be retreived using collect
    event CanCollect(address player);
    // notifies the players of this round that both of them have committed so they should now reveal
    event CanReveal(address player);

    /**
     * Reveals the choices made by a player of this round
     * The values given should be hashable to the respective values committed by this player
     * The two numbers for this player are the last character of each string given (should be ending with a number)
     */
    function revealPlayer(guess storage player, string memory myNumber, string memory guessedValue) internal {
        require(player.myNumber == NOT_RVLD, 'You have already revealed');
        require(keccak256(bytes(myNumber)) == player.hashMyNumber, 'Your picked value doesn\'t match its hash.');
        require(keccak256(bytes(guessedValue)) == player.hashGuessedNumber, 'Your guess of the other\'s number doesn\'t match its hash.');
        // get the last character out of the string as an integer
        uint8 valueGiven = getNumber(myNumber);
        // if the player picked a number that is not in the range, don't let them reveal.
        require(valueGiven >= 1 && valueGiven <= 5, 'You should have picked a number [1,5]. You\'re out of the game for this round');
        player.myNumber = valueGiven;
        player.guessedNumber = getNumber(guessedValue);
    }

    /**
     * Given a string that ends in a number 0-9, return that number as an int.
     * This is possible because numbers in UTF-8 are single byte long.
     * If the last character is not an integer in the range [1,5] then return 0 indicating invalid string
     */
    function getNumber(string memory textEndingWithNumber) internal pure returns (uint8 ret) {
        bytes memory bstring = bytes(textEndingWithNumber);
        byte last = bstring[bstring.length - 1];
        if (last == "1") return 1;
        else if (last == "2") return 2;
        else if (last == "3") return 3;
        else if (last == "4") return 4;
        else if (last == "5") return 5;
        // invalid original string
        return 0;
    }

    /**
     * checks if the given player has won the round by guessing the other player's picked number
     */
    function didPlayerWin(uint8 playerIndex) internal view returns (bool) {
        uint8 otherIndex = (playerIndex + 1) % 2;
        return guesses[playerIndex].guessedNumber == guesses[otherIndex].myNumber;
    }

    /**
     * Distributes the rewards at the end of the round, as follows:
     *  if both players won: return to each the price they payed to play
     *  if only one of them won: return to the winner the their reward, i.e. the sum of the two numbers
     *      guessed by each player plus the difference between the guessed number and what they've payed to play
     *  if no player won: they both get nothing back
     */
    function distributeReward() internal {
        assert(address(this).balance >= 2 * gamePrice);
        assert(guesses.length == 2);
        assert(guesses[0].myNumber != NOT_RVLD && guesses[1].myNumber != NOT_RVLD);
        uint256 sum = (guesses[0].guessedNumber + guesses[1].guessedNumber) * gamePriceUnit;
        assert(sum <= 2 * gamePrice);
        bool player0won = didPlayerWin(0);
        bool player1won = didPlayerWin(1);
        if (player0won && player1won) {
            refunds[guesses[0].player] = gamePrice;
            refunds[guesses[1].player] = gamePrice;
            // notify players to collect
            emit CanCollect(guesses[0].player);
            emit CanCollect(guesses[1].player);
        } else if (player0won) {
            // refund the sum plus any surplus from the difference between price of game and the value paid by winning player
            refunds[guesses[0].player] = (gamePrice - guesses[0].guessedNumber * gamePriceUnit) + sum;
            // notify player to collect
            emit CanCollect(guesses[0].player);
            refunds[guesses[1].player] = 0;
        } else if (player1won) {
            refunds[guesses[0].player] = 0;
            refunds[guesses[1].player] = (gamePrice - guesses[1].guessedNumber * gamePriceUnit) + sum;
            // notify player to collect
            emit CanCollect(guesses[1].player);
        }
    }

    /**
     * Forces a game to end even if not both players haven't revealed yet.
     * If none of the players have revealed, the game restarts without giving any rewards
     *    because they should have revealed in time.
     * If only one of them reveals, then the other one looses the game by setting his choices
     *    such as the revealed player would have guessed correctly
     * There can't be a case where this method is called and both of them have revealed because
     *    when the last player reveals, then the game is automatically restarted.
     */
    function forceGameEnd() internal {
        assert(guesses.length == 2);
        // at least one player hasn't revealed
        assert(guesses[0].myNumber == NOT_RVLD || guesses[1].myNumber == NOT_RVLD);
        bool p0 = guesses[0].myNumber != NOT_RVLD;
        bool p1 = guesses[1].myNumber != NOT_RVLD;
        // if only one has already revealed, make them a winner
        if (p0 != p1) {
            uint8 revealedPlayerIndex = p0 ? 0 : 1;
            uint8 unrevealedPlayerIndex = (revealedPlayerIndex + 1) % 2;
            // manually set the choices of the player who didn't reveal, in the most favorable way to
            // the player who revealed.
            uint8 manualGuess = guesses[revealedPlayerIndex].myNumber == 5 ? 4 : 5;
            guesses[unrevealedPlayerIndex].guessedNumber = manualGuess;
            guesses[unrevealedPlayerIndex].myNumber = guesses[revealedPlayerIndex].guessedNumber;
            distributeReward();
        }
        restartGame();
    }

    /**
     * End the game even if some players haven't revealed yet.
     * This is required to prevent non revealing players blocking the game because
     * they forgot to reveal or because one of them revealed and the other one realized that they lost
     * and they don't have an interest to reveal.
     * This can only be called both players have committed and they haven't both revealed
     * until the game has expired
     */
    function endExpiredGame() internal {
        bool isExpired = isGameExpired();
        require(isExpired, 'Game hasn\'t expired yet');
        if (isExpired) {
            forceGameEnd();
        }
    }

    /**
     * Reinitializes game by resetting expiry clock and removing current session players.
     */
    function restartGame() internal {
        guesses.length = 0;
        timeOfGame = 0;
    }

    /*
     * Allows a player to enter this round of the game by submitting their choices as hashed values.
     * Players need to pay the game price to play, which will be returned along with a prize in the case of a win.
     * @param hashValue: hash of a string ending with a desired number [1,5], e.g. abcd3, where the number represents
     *  the player's selected number
     * @param hashOtherValue: hash of a string ending with a desired number [1,5], e.g. cdg2, where the number represents
     *  the other guess of the other player's number
     *
     * P.S. you can use https://emn178.github.io/online-tools/keccak_256.html to calculate hash
    */
    function submitGuess(bytes32 hashValue, bytes32 hashOtherValue) public payable {
        //if the previous game expired and nobody terminated yet, end the previous game to allow the next round to go on.
        if (isGameExpired()) {
            restartGame();
        }
        require(guesses.length < 2, 'Both players have already played');
        require(msg.value >= gamePrice, 'Need to pay 5 ether to play. Nothing is free');
        // register player's guess, with specific not-yet-revealed values for the two numbers
        uint newLength = guesses.push(guess(msg.sender, NOT_RVLD, hashValue, NOT_RVLD, hashOtherValue));
        if (newLength == 2) {
            // notify players to reveal
            emit CanReveal(guesses[0].player);
            emit CanReveal(guesses[1].player);
            timeOfGame = now;
        }
    }

    /*
     * Reveals a player's choice of the two strings that end with the desired numbers, whose hashes have been
     *   submitted when entering the game.
     * Should be a player who is playing for this round and the values should match their hashes
     * @param revealedValue: value of the hashed string that represents this player's choice of own number
     * @param otherRevealedValue: value of the hashed string that represents this player's guess of the other player's choice of own number
     */
    function reveal(string memory revealedValue, string memory otherRevealedValue) public {
        require(guesses.length == 2, 'Both players need to commit first');
        if (msg.sender == guesses[0].player) {
            revealPlayer(guesses[0], revealedValue, otherRevealedValue);
        } else if (msg.sender == guesses[1].player) {
            revealPlayer(guesses[1], revealedValue, otherRevealedValue);
        } else {
            require(false, 'Wait for the next round to play.');
        }
        bool bothRevealed = guesses[0].myNumber != NOT_RVLD && guesses[1].myNumber != NOT_RVLD;
        if (bothRevealed) {
            distributeReward();
            restartGame();
        }
    }

    function isGameExpired() public view returns (bool) {
        if (timeOfGame == 0) return false;
        return maxTimeTillGameExpiry < int(now - timeOfGame);
    }

    /**
     * Allows a player to withdraw their rewards, if they have any
     * If the caller is a player of the current round and the game is expired,
     * then the current game is terminated, giving the chance to any revealed player to collect.
     */
    function collect() public returns (uint256) {
        if (isGameExpired() && (msg.sender == guesses[0].player || msg.sender == guesses[1].player)) {
            endExpiredGame();
        }
        uint256 value = refunds[msg.sender];
        require(value > 0, 'There is no refunds available for you');
        // update state and then transfer
        refunds[msg.sender] = 0;
        msg.sender.transfer(value);
        return value;
    }
}