// SPDX-License-Identifier: MIT
pragma solidity >=0.8.18 <=0.8.20;

import {Test} from "forge-std/Test.sol";
import {VotingContract} from "../src/VotingContract.sol";

contract VotingContractTest is Test {
    VotingContract votingContract;
    address admin = address(1);
    address voter1 = address(2);
    address voter2 = address(3);
    address newWalletForVoter1 = address(4);

    function setUp() public {
        vm.prank(admin);
        votingContract = new VotingContract(admin);

        vm.prank(voter1);
        votingContract.registerVoter("Alice", "Computer Science", "CS123", 3);
        vm.prank(voter2);
        votingContract.registerVoter(
            "Bob",
            "Mechanical Engineering",
            "ME456",
            2
        );
    }

    function testGetAdmin() public view {
        address calledAdmin = votingContract.getAdmin();

        assertEq(calledAdmin, admin);
    }

    function testRegisterVoter() public view {
        (
            string memory name,
            string memory department,
            string memory regNumber,
            uint yearOfStudy,
            bool hasVoted
        ) = votingContract.getVoter(voter1);
        assertEq(name, "Alice");
        assertEq(department, "Computer Science");
        assertEq(regNumber, "CS123");
        assertEq(yearOfStudy, 3);
        assertEq(hasVoted, false);
    }

    function testAddCandidate() public {
        vm.startPrank(admin);
        votingContract.addCandidate(
            "Charlie",
            "Electrical Engineering",
            "EE789",
            4,
            "President"
        );
        vm.stopPrank();

        VotingContract.Candidate[] memory candidates = votingContract
            .getCandidates("President");
        assertEq(candidates.length, 1);
        assertEq(candidates[0].name, "Charlie");
        assertEq(candidates[0].department, "Electrical Engineering");
        assertEq(candidates[0].regNumber, "EE789");
        assertEq(candidates[0].yearOfStudy, 4);
        assertEq(candidates[0].position, "President");
        assertEq(candidates[0].voteCount, 0);
    }

    function testStartAndEndVoting() public {
        vm.startPrank(admin);
        votingContract.startVoting();
        assertEq(votingContract.s_votingStarted(), true);
        assertEq(votingContract.s_votingEnded(), false);

        votingContract.endVoting();
        assertEq(votingContract.s_votingStarted(), false);
        assertEq(votingContract.s_votingEnded(), true);
        vm.stopPrank();
    }

    function testVote() public {
        vm.startPrank(admin);
        votingContract.addCandidate(
            "Charlie",
            "Electrical Engineering",
            "EE789",
            4,
            "President"
        );
        votingContract.startVoting();
        vm.stopPrank();

        vm.prank(voter1);
        votingContract.vote("President", 0);

        uint voteCount = votingContract.getVoteCount("President", 0);
        assertEq(voteCount, 1);
    }

    function testDeclareWinners() public {
        vm.startPrank(admin);
        votingContract.addCandidate(
            "Charlie",
            "Electrical Engineering",
            "EE789",
            4,
            "President"
        );
        votingContract.addCandidate(
            "David",
            "Mechanical Engineering",
            "ME012",
            3,
            "President"
        );
        votingContract.startVoting();
        vm.stopPrank();

        vm.prank(voter1);
        votingContract.vote("President", 0);

        vm.prank(voter2);
        votingContract.vote("President", 0);

        vm.prank(admin);
        votingContract.endVoting();

        // Check the winner using the new getWinner function
        (string memory winnerName, uint winnerVoteCount) = votingContract.getWinner("President");

        assertEq(winnerName, "Charlie");
        assertEq(winnerVoteCount, 2);
    }

    function testAddCandidateTwice() public {
        vm.startPrank(admin);
        votingContract.addCandidate(
            "Charlie",
            "Electrical Engineering",
            "EE789",
            4,
            "President"
        );
        vm.expectRevert(
            VotingContract
                .VotingContract__CandidateAlreadyExistsForThisPosition
                .selector
        );
        votingContract.addCandidate(
            "Charlie",
            "Electrical Engineering",
            "EE789",
            4,
            "President"
        );
        vm.stopPrank();
    }

    function testGetWinner_AfterMultipleVotes() public {
        vm.startPrank(admin);
        votingContract.addCandidate(
            "Charlie",
            "Electrical Engineering",
            "EE789",
            4,
            "President"
        );
        votingContract.startVoting();
        vm.stopPrank();

        vm.prank(voter1);
        votingContract.vote("President", 0); // Charlie gets 1 vote

        vm.prank(voter2);
        votingContract.vote("President", 0); // Charlie gets another vote

        vm.prank(admin);
        votingContract.endVoting();

        // Retrieve the winner
        (string memory winnerName, uint winnerVoteCount) = votingContract.getWinner("President");

        // Check that Charlie is the winner with 2 votes
        assertEq(winnerName, "Charlie");
        assertEq(winnerVoteCount, 2);
    }

     function testVoteTwiceForSamePosition() public {
        vm.startPrank(admin);
        votingContract.addCandidate(
            "Charlie",
            "Electrical Engineering",
            "EE789",
            4,
            "President"
        );
        votingContract.startVoting();
        vm.stopPrank();

        vm.prank(voter1);
        votingContract.vote("President", 0);

        vm.prank(voter1);
        vm.expectRevert(VotingContract.VotingContract__YouHaveAlreadyVotedForThisPosition.selector);
        votingContract.vote("President", 0);
    }

    function testRegisterVoterTwiceWithDifferentWallet() public {
        // Registering voter1 with a new wallet but same registration number
        vm.prank(newWalletForVoter1);
        vm.expectRevert(VotingContract.VotingContract__RegistrationNumberAlreadyUsed.selector);
        votingContract.registerVoter("Alice", "Computer Science", "CS123", 3);
    }

    function testVoteAfterSwitchingWallets() public {
        vm.startPrank(admin);
        votingContract.addCandidate(
            "Charlie",
            "Electrical Engineering",
            "EE789",
            4,
            "President"
        );
        votingContract.startVoting();
        vm.stopPrank();

        // Voter1 votes with original wallet
        vm.prank(voter1);
        votingContract.vote("President", 0);

        // Voter1 tries to vote with a different wallet
        vm.prank(newWalletForVoter1);
        vm.expectRevert(VotingContract.VotingContract__YouMustBeRegisteredToVote.selector);
        votingContract.vote("President", 0);
    }
}
