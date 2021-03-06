public with sharing class DebugEntryService {
    @testvisible
    private static Boolean userHasCustomPermissionOverride = false;

    public static void saveLogs(List<PELog__e> logs) {
        LoggerConfig config = LoggerConfig.getConfig();
        List<DebugEntry__c> newDebugEntries = new List<DebugEntry__c>();
        Map<Id, User> UserWithPermissionSetAssignments = new Map<Id, User>();

        if (config.saveUserLogs) {
            UserWithPermissionSetAssignments = setupCustomPermissionMap(logs);
        }

        for (PELog__e log : logs) {
            Boolean processDebugEntry = false;

            List<String> traceInfo = log.Trace__c.split(':');
            if (!isValid(traceInfo)) {
                return;
            }
            DebugEntry__c entry = new DebugEntry__c();
            entry.className__c = traceInfo[0];
            entry.methodName__c = traceInfo[1];
            entry.Line__c = Integer.ValueOf(traceInfo[2]);
            entry.Column__c = Integer.ValueOf(traceInfo[3]);
            entry.cpuTimeUsage__c = Integer.ValueOf(traceInfo[4]);
            entry.runningUser__c = traceInfo[5];
            entry.startDateTime__c = log.startDateTime__c;
            entry.logEntryJSON__c = log.LogEntriesJSON__c;
            entry.TriggerOperation__c = log.TriggerOperation__c;
            entry.transactionUUID__c = log.transactionUUID__c;
            if (config.saveAllLogs) {
                processDebugEntry = true;
            } else if (config.saveExceptionLogs && log.isException__c) {
                processDebugEntry = true;
            } else if (config.saveUserLogs) {
                List<PermissionSetAssignment> assignments = UserWithPermissionSetAssignments.get(log.CreatedById)
                    .permissionsetAssignments;
                for (PermissionSetAssignment assignment : assignments) {
                    if (assignment.PermissionSet.Name == 'EnableLoggingForUser') {
                        processDebugEntry = true;
                        break;
                    }
                }
                if (Test.isRunningTest()) {
                    processDebugEntry = userHasCustomPermissionOverride;
                }
            } else if (
                !String.isNotBlank(config.classNamesToLog) && config.classNamesToLog.contains(entry.className__c)
            ) {
                processDebugEntry = true;
            }

            if (processDebugEntry) {
                newDebugEntries.add(entry);
            }
        }
        insert newDebugEntries;
    }

    private static Map<Id, User> setupCustomPermissionMap(List<PELog__e> logs) {
        List<Id> userIds = new List<Id>();
        for (PELog__e log : logs) {
            userIds.add(log.CreatedById);
        }
        Map<ID, User> usersMap = new Map<ID, User>(
            [
                SELECT
                    id,
                    (
                        SELECT id, permissionSetId, permissionSet.label, permissionSet.name
                        FROM PermissionSetAssignments
                        WHERE permissionSet.isOwnedByProfile = false
                    )
                FROM User
                WHERE id IN :userIds
            ]
        );
        return usersmap;
    }

    private static Boolean isValid(List<String> traceInfo) {
        return traceInfo != null && traceInfo.size() == 6;
    }
}
