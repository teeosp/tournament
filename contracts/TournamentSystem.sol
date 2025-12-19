// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ZamaEthereumConfig} from "@fhevm/solidity/config/ZamaConfig.sol";
import {FHE} from "@fhevm/solidity/lib/FHE.sol";
import {euint32} from "@fhevm/solidity/lib/FHE.sol";

// tournament system with encrypted results
contract TournamentSystem is ZamaEthereumConfig {
    struct Tournament {
        address organizer;
        string name;
        uint256 startTime;
        uint256 endTime;
        euint32 prizePool;  // encrypted
        bool active;
    }
    
    struct Participant {
        address player;
        euint32 score;      // encrypted
        bool eliminated;
    }
    
    mapping(uint256 => Tournament) public tournaments;
    mapping(uint256 => Participant[]) public participants;
    uint256 public tournamentCounter;
    
    event TournamentCreated(uint256 indexed tournamentId, address organizer);
    event PlayerRegistered(uint256 indexed tournamentId, address player);
    event TournamentEnded(uint256 indexed tournamentId, address winner);
    
    function createTournament(
        string memory name,
        uint256 duration,
        euint32 encryptedPrizePool
    ) external returns (uint256 tournamentId) {
        tournamentId = tournamentCounter++;
        tournaments[tournamentId] = Tournament({
            organizer: msg.sender,
            name: name,
            startTime: block.timestamp,
            endTime: block.timestamp + duration,
            prizePool: encryptedPrizePool,
            active: true
        });
        emit TournamentCreated(tournamentId, msg.sender);
    }
    
    function register(uint256 tournamentId) external {
        Tournament storage tournament = tournaments[tournamentId];
        require(tournament.active, "Tournament not active");
        require(block.timestamp < tournament.endTime, "Tournament ended");
        
        participants[tournamentId].push(Participant({
            player: msg.sender,
            score: FHE.asEuint32(0),
            eliminated: false
        }));
        
        emit PlayerRegistered(tournamentId, msg.sender);
    }
    
    function updateScore(
        uint256 tournamentId,
        euint32 encryptedScore
    ) external {
        Tournament storage tournament = tournaments[tournamentId];
        require(tournament.active, "Tournament not active");
        
        // find and update participant score
        for (uint256 i = 0; i < participants[tournamentId].length; i++) {
            if (participants[tournamentId][i].player == msg.sender) {
                participants[tournamentId][i].score = encryptedScore;
                break;
            }
        }
    }
    
    function endTournament(uint256 tournamentId) external {
        Tournament storage tournament = tournaments[tournamentId];
        require(tournament.organizer == msg.sender, "Not organizer");
        require(block.timestamp >= tournament.endTime, "Still active");
        
        tournament.active = false;
        
        // find winner (would need decryption for final step)
        if (participants[tournamentId].length > 0) {
            emit TournamentEnded(tournamentId, participants[tournamentId][0].player);
        }
    }
}

