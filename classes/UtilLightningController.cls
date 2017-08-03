public class UtilLightningController {

    @AuraEnabled
    public static List<sObject> lookupSearch(String sObjectName, String searchString, String[] fields) {
        String query = 'SELECT ' + String.join(fields,',') + ' FROM ' + sObjectName + ' WHERE Name LIKE \'' + searchString + '%\'';
        System.debug(query);
        return database.query(query);
    }
}