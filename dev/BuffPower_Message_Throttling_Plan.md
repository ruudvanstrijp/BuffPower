# BuffPower Addon: Raid CPU Issue Analysis and Mitigation Plan

## Problem Summary

- In **large raids** (20-40 players), enabling BuffPower leads to extremely high CPU usage, especially in conjunction with DataStore.
- In small groups or solo play, there is no noticeable issue.
- Code review shows BuffPower sends assignment messages ("ASSIGN_GROUP", etc.) via `SendAddonMessage` to the RAID/PARTY channel, especially in response to "REQ_ASSIGN" messages from other BuffPower users.

## Cause

- In a raid, when a user requests assignments ("REQ_ASSIGN"), all BuffPower users respond **with a message per assignment**. With multiple BuffPower users and group assignments in a large raid, the number of messages grows rapidly.
- Every message triggers parsing by all addons listening to addon communications, including DataStore, which may not filter out unknown prefixes efficiently, resulting in high aggregate CPU usage ("message storm").
- Most WoW comm-centric addons are affected by exponential traffic in full raids if not properly rate-limited.

## Remediation Plan

### 1. Throttle Assignment Replies

#### Implementation
- Introduce throttling logic (e.g., do **not** send more than 1 reply per sender per N seconds, or bundle all assignments into a single reply if possible).
- Only allow sending assignment replies if at least X seconds have passed since last reply (per user, raid-wide if feasible).
- Example (concept):
    ```lua
    local lastReplyTime = 0
    function BuffPower:OnAddonMessage(prefix, message, channel, sender)
        if message == "REQ_ASSIGN" then
            local now = GetTime()
            if now - lastReplyTime > 1 then  -- 1 second cooldown
                lastReplyTime = now
                -- send assignment(s)
            end
        end
    end
    ```
- Optionally, consider only responding to assignment requests if you are **officer or raid leader** in big raid groups (to reduce redundant traffic even further).

### 2. Make Comm Prefix As Unique As Possible

- Ensure BuffPower uses a distinct prefix (e.g. "BuffPower1") so other addons can ignore its messages quickly.

### 3. Technical Diagram

```mermaid
sequenceDiagram
    participant BuffPowerUser as BuffPower User(s)
    participant Raid as Raid Members
    participant DataStore

    BuffPowerUser->>Raid: SendAddonMessage("REQ_ASSIGN")
    Note over Raid: All BuffPower users receive "REQ_ASSIGN"

    loop Every user (current: responds for each assignment immediately)
      BuffPowerUser->>Raid: SendAddonMessage("ASSIGN_GROUP ...") (multiple per user)
      DataStore-->>DataStore: Parse every message (high CPU)
    end

    alt Proposal: Throttled Mode
      BuffPowerUser->>Raid: SendAddonMessage("ASSIGN_GROUP ...") (throttled; 1/sec or bundled)
      DataStore-->>DataStore: Lower parsing volume (reduced CPU)
    end
```

### 4. What Will Change

- Drastically fewer "ASSIGN_GROUP" replies when multiple users request assignments in a short window, especially in raid size environments.
- DataStore and similar addons will have much less traffic to parse, avoiding the CPU "storm" effect.
- BuffPower functionality in small groups or solo play will remain unchanged.

## Recommendation

- **Implement the above throttling as the primary fix.**
- Optionally add a debug print when throttling occurs.
- Document this in the dev folder for reference.

---

**Please review this plan. If it meets your expectations, confirm and I can proceed to implementation or create additional documentation as needed.**