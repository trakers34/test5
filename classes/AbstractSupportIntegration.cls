@RestResource(urlMapping='/support/v1/*')
global abstract class AbstractSupportIntegration{
    global abstract Map<String,Object> handle(Map<String,String> paramRequestParameters);

    global static final Map<String,Map<String,Object>> handlers = new Map<String,Map<String,Object>>{
        '/login'                    =>  new Map<String,Object>{'Handler'=>Login.class},
        '/projects'                 =>  new Map<String,Object>{'Handler'=>Projects.class},
        '/customer'                 =>  new Map<String,Object>{'Handler'=>Customer.class},
        '/case'                     =>  new Map<String,Object>{},
        '/case/new'                 =>  new Map<String,Object>{'Handler'=>CaseNew.class},
        '/case/view'                =>  new Map<String,Object>{'Handler'=>CaseView.class},
        '/case/list'                =>  new Map<String,Object>{'Handler'=>CaseList.class},
        '/case/comment'             =>  new Map<String,Object>{'Handler'=>CaseNewComment.class},
        '/case/close'               =>  new Map<String,Object>{'Handler'=>CaseClose.class},
        '/case/example'             =>  new Map<String,Object>{'Handler'=>CaseView.class},
        '/case/sample'              =>  new Map<String,Object>{'Handler'=>CaseView.class},
        '/case/instance'            =>  new Map<String,Object>{'Handler'=>CaseView.class},
        '/quotes'                   =>  new Map<String,Object>{'Handler'=>Quotes.class}
        
    };



    @HttpGet
    global static void doGet() {
        RestContext.response.statusCode = 400;
        RestContext.response.headers.put('Content-Type','application/json');
        RestContext.response.responseBody = Blob.valueOf('{"status":"400"}');
    }

    @HttpPost
    global static void doPost() {
        
        RestRequest req = RestContext.request;
        String relativeURI = req.requestURI.split('\\?')[0].split('/support/v1/')[1];
        List<String> splitRelativeURI = relativeURI.split('/');
        String handlerURI = '';


        for (String forCurrentPath : splitRelativeURI) {

            if(handlers.get(handlerURI + '/' + forCurrentPath) != null) {
                handlerURI += '/' + forCurrentPath;
            
            } else if (handlers.get(handlerURI + '/*') != null) {
                handlerURI += '/*';
            
            } else {
                handlerURI = null;
                break;
            }
        }
        
        System.debug(splitRelativeURI);
        if (handlerURI == null) {
            RestContext.response.statusCode = 404;
        
        } else {
            Type handler = (Type)handlers.get(handlerURI).get('Handler');
            AbstractSupportIntegration asi = (AbstractSupportIntegration)handler.newInstance();
            Map<String,String> requestParameters = RestContext.request.params;
            
            Object returned = asi.handle(requestParameters);
            
                RestContext.response.responseBody = Blob.valueOf(Json.serializePretty(returned));
                System.debug(Json.serializePretty(returned));
                RestContext.response.headers.put('parameters','' + requestParameters);
        }
    }

/**
            LOGIN
**/
    global class Login extends AbstractSupportIntegration {
        
        global override Map<String,Object> handle(Map<String,String> paramRequestParameters) {
            Map<String,Object> returned = new Map<String,Object>();
            RestRequest req = RestContext.request;

            Map<String,String> requestData = (Map<String,String>)JSON.deserialize(req.requestBody.toString(), Map<String,String>.class);
			if(requestData.get('username') != null && requestData.get('username') != '' &&
               requestData.get('password') != null && requestData.get('password') != ''){
                List<Account> accounts = [SELECT Name, CustomerPortalEnabled__c, CustomerPortalPassword__c FROM Account WHERE CustomerPortalUsername__c = :requestData.get('username')];
    
                if(accounts.size()==0) {
                    returned.put('status','404');
                    returned.put('message','Account Not found');
                } else if (accounts.get(0).CustomerPortalEnabled__c == false) {
                    returned.put('status','400');
                    returned.put('message','Account not Activated for Support portal');
                } else if (accounts.get(0).CustomerPortalPassword__c != requestData.get('password')) {
                    returned.put('status','401');
                    returned.put('message','Invalid Password');
                } else {
                    returned.put('status','200');
                    returned.put('data',new Map<String,String>{
                       'accountId'=>accounts.get(0).Id,
                       'accountName'=>accounts.get(0).Name
                    });    
                }
            } else {
            	returned.put('status','400');
                returned.put('message','Username and password are required');
            }
            return returned;
        }
    }
/**
    PROJECTS
**/
    global class Projects extends AbstractSupportIntegration {
        
        global override Map<String,Object> handle(Map<String,String> paramRequestParameters) {
            Map<String,Object> returned = new Map<String,Object>();
            RestRequest req = RestContext.request;

            Map<String,String> requestData = (Map<String,String>)JSON.deserialize(req.requestBody.toString(), Map<String,String>.class);
            if(requestData.get('accountId') != null && requestData.get('accountId') != ''){
                System.debug(requestData.get('accountId'));
    
                returned.put('status','200');

                List<Map<String,Object>> data = new List<Map<String,Object>>();
                for(Opportunity forOpp : [SELECT Name, StageName, BillingType__c, HoursInBundle__c FROM Opportunity WHERE AccountId = :requestData.get('accountId') AND DisplayInCustomerPortal__c = true]){
                    data.add(new Map<String,Object>{
                        'name'=>forOpp.Name,
                        'billingType'=>forOpp.BillingType__c,
                        'hoursInBundle'=>forOpp.HoursInBundle__c,
                        'isBundle'=>forOpp.BillingType__c == 'Bundle of Hours',
                        'stage'=>forOpp.StageName,
                        'id'=>forOpp.Id
                    });
                }
                returned.put('data',data);

            } else {
                returned.put('status','400');
                returned.put('message','accountId is required');
            }
            return returned;
        }
    }
/**
    Account
**/
    global class Customer extends AbstractSupportIntegration {
        
        global override Map<String,Object> handle(Map<String,String> paramRequestParameters) {
            Map<String,Object> returned = new Map<String,Object>();
            RestRequest req = RestContext.request;

            Map<String,String> requestData = (Map<String,String>)JSON.deserialize(req.requestBody.toString(), Map<String,String>.class);
            if(requestData.get('accountId') != null && requestData.get('accountId') != ''){

                List<Map<String,String>> data = new List<Map<String,String>>();
                List<Account> currentAccount = [SELECT Name, CustomerSinceAuto__c, OpportunitiesWonAuto__c FROM Account WHERE Id = :requestData.get('accountId')];

                if(currentAccount.size() == 0){
                    returned.put('status','400');
                    returned.put('message', 'Account not found');
                } else {
                    returned.put('status','200');
                    returned.put('data', new Map<String,String>{
                        'customerSince' => (currentAccount[0].CustomerSinceAuto__c == null?' - ':currentAccount[0].CustomerSinceAuto__c.day() + ' / ' + currentAccount[0].CustomerSinceAuto__c.month() + ' / ' + currentAccount[0].CustomerSinceAuto__c.year()),
                        'customerName' => currentAccount[0].Name,
                        'numberOfProjects' => String.valueOf(currentAccount[0].OpportunitiesWonAuto__c)
                    });
                }

            } else {
                returned.put('status','400');
                returned.put('message','accountId is required');
            }
            return returned;
        }
    }

/**
    Case New
**/
    global class CaseNew extends AbstractSupportIntegration {

        global override Map<String,Object> handle(Map<String,String> paramRequestParameters) {
            Map<String,Object> returned = new Map<String,Object>();
            RestRequest req = RestContext.request;

            Map<String,String> requestData = (Map<String,String>)JSON.deserialize(req.requestBody.toString(), Map<String,String>.class);
            if(requestData.get('accountId') != null && requestData.get('accountId') != '') {
                Case theCase = new Case(
                    AccountId = requestData.get('accountId'),
                    Subject = requestData.get('subject'),
                    Description = requestData.get('description'),
                    Priority = requestData.get('priority'),
                    Reason = requestData.get('type'),
                    Origin = 'Portal');

                try {
                    insert theCase;
                    returned.put('status','200');
                    returned.put('data', new Map<String,String>{
                        'caseId' => theCase.Id
                    });
                } catch (Exception e) {
                    returned.put('status','500');
                    returned.put('message',e.getMessage());
                }
            } else {
                returned.put('status','400');
                returned.put('message','accountId is required');
            }
            return returned;
        }
    }

/**
    Case View
**/
    global class CaseView extends AbstractSupportIntegration {
        
        global override Map<String,Object> handle(Map<String,String> paramRequestParameters) {
            Map<String,Object> returned = new Map<String,Object>();
            RestRequest req = RestContext.request;

            Map<String,String> requestData = (Map<String,String>)JSON.deserialize(req.requestBody.toString(), Map<String,String>.class);
            if(requestData.get('accountId') != null && requestData.get('accountId') != '' &&
                requestData.get('caseId') != null && requestData.get('caseId') != ''){

                List<Map<String,String>> data = new List<Map<String,String>>();
                List<Case> currentCases = [SELECT CaseNumber, Status, CreatedDate, Subject, Description, Priority, Reason, (SELECT CommentBody FROM CaseComments ORDER BY CreatedDate DESC) FROM Case WHERE Id = :requestData.get('caseId') AND AccountId = :requestData.get('accountId')];

                if(currentCases.size() == 0){
                    returned.put('status','400');
                    returned.put('message', 'Case not found');
                } else {
                    returned.put('status','200');
                    Case currentCase = currentCases[0];
                    String createdDate = String.format('{0}:{1} {2} / {3} / {4}', new List<String>{
                            String.valueOf(currentCase.CreatedDate.hour()),
                            String.valueOf(currentCase.CreatedDate.minute()),
                            String.valueOf(currentCase.CreatedDate.day()),
                            String.valueOf(currentCase.CreatedDate.month()),
                            String.valueOf(currentCase.CreatedDate.year())
                        });

                    returned.put('data', new Map<String,Object>{
                        'id' => currentCase.Id,
                        'caseNumber' => currentCase.CaseNumber,
                        'status' => currentCase.Status,
                        'isClosed' => currentCase.Status == 'Closed',
                        'createdDate' => createdDate,
                        'subject' => currentCase.Subject,
                        'description' => currentCase.Description,
                        'priority' => currentCase.Priority,
                        'reason' => currentCase.Reason,
                        'comments' => currentCase.CaseComments
                    });
                }

            } else {
                returned.put('status','400');
                returned.put('message','accountId and caseId are required');
            }
            return returned;
        }
    }

/**
    Case List
**/
    global class CaseList extends AbstractSupportIntegration {
        
        global override Map<String,Object> handle(Map<String,String> paramRequestParameters) {
            Map<String,Object> returned = new Map<String,Object>();
            RestRequest req = RestContext.request;

            Map<String,String> requestData = (Map<String,String>)JSON.deserialize(req.requestBody.toString(), Map<String,String>.class);
            if(requestData.get('accountId') != null && requestData.get('accountId') != ''){

                List<Map<String,Object>> data = new List<Map<String,Object>>();

                returned.put('status','200');

                for (Case forCase : [SELECT CaseNumber, CreatedDate, Status, Subject, Priority, Reason FROM Case WHERE AccountId = :requestData.get('accountId')]) {
                    returned.put('status','200');
                    String createdDate = String.format('{0}/{1}/{2}', new List<String>{
                            String.valueOf(forCase.CreatedDate.day()),
                            String.valueOf(forCase.CreatedDate.month()),
                            String.valueOf(forCase.CreatedDate.year())
                        });

                    String createdTime = String.format('{0} : {1}', new List<String>{
                            (forCase.CreatedDate.hour() > 9?'':'0') + String.valueOf(forCase.CreatedDate.hour()),
                            (forCase.CreatedDate.minute() > 9?'':'0') + String.valueOf(forCase.CreatedDate.minute())
                        });

                    data.add(new Map<String,String>{
                        'id' => forCase.Id,
                        'caseNumber' => forCase.CaseNumber,
                        'createdDate' => createdDate,
                        'createdTime' => createdTime,
                        'status' => forCase.Status,
                        'subject' => forCase.Subject,
                        'priority' => forCase.Priority,
                        'reason' => forCase.Reason
                    });
                }
                returned.put('data',data);

            } else {
                returned.put('status','400');
                returned.put('message','accountId is required');
            }
            return returned;
        }
    }

/**
    Case Comment
**/
    global class CaseNewComment extends AbstractSupportIntegration {

        global override Map<String,Object> handle(Map<String,String> paramRequestParameters) {
            Map<String,Object> returned = new Map<String,Object>();
            RestRequest req = RestContext.request;

            Map<String,String> requestData = (Map<String,String>)JSON.deserialize(req.requestBody.toString(), Map<String,String>.class);
            if(requestData.get('accountId') != null && requestData.get('accountId') != '' &&
                requestData.get('caseId') != null && requestData.get('caseId') != '' &&
                requestData.get('comment') != null && requestData.get('comment').trim() != '') {

                if([SELECT Count() FROM Case WHERE Id = :requestData.get('caseId') AND AccountId = :requestData.get('accountId')] == 0){
                    returned.put('status','400');
                    returned.put('message','Case not found');
                } else {
                    CaseComment theCaseComment = new CaseComment(
                        CommentBody = requestData.get('comment'),
                        ParentId = requestData.get('caseId'));
                
                    try {
                        insert theCaseComment;
                        returned.put('status','200');
                    } catch (Exception e) {
                        returned.put('status','500');
                        returned.put('message',e.getMessage());
                    }
                }

            } else {
                returned.put('status','400');
                returned.put('message','Required fields missing');
            }
            return returned;
        }
    }

/**
    Case Close
**/
    global class CaseClose extends AbstractSupportIntegration {

        global override Map<String,Object> handle(Map<String,String> paramRequestParameters) {
            Map<String,Object> returned = new Map<String,Object>();
            RestRequest req = RestContext.request;

            Map<String,String> requestData = (Map<String,String>)JSON.deserialize(req.requestBody.toString(), Map<String,String>.class);
            if(requestData.get('accountId') != null && requestData.get('accountId') != '' &&
                requestData.get('caseId') != null && requestData.get('caseId') != '') {

                List<Case> cases = [SELECT Id FROM Case WHERE Id = :requestData.get('caseId') AND AccountId = :requestData.get('accountId')];

                if(cases.size() == 1) {
                    try {
                        update new Case(Id=cases.get(0).Id, Status='Closed');
                        returned.put('status','200');
                    } catch (Exception e) {
                        returned.put('status','500');
                        returned.put('message',e.getMessage());
                    }
                } else {
                    returned.put('status','404');
                    returned.put('message','Case not found');
                }
            } else {
                returned.put('status','400');
                returned.put('message','Required fields missing');
            }
            return returned;
        }
    }

/**
    Quotes List
**/
    global class Quotes extends AbstractSupportIntegration {
        
        global override Map<String,Object> handle(Map<String,String> paramRequestParameters) {
            Map<String,Object> returned = new Map<String,Object>();
            RestRequest req = RestContext.request;

            Map<String,String> requestData = (Map<String,String>)JSON.deserialize(req.requestBody.toString(), Map<String,String>.class);
            if(requestData.get('accountId') != null && requestData.get('accountId') != '' &&
                requestData.get('opportunityId') != null && requestData.get('opportunityId') != ''){

                List<Map<String,Object>> data = new List<Map<String,Object>>();
                for(Quote forQuote : [SELECT Name, Status, Opportunity.Name, Subtotal, (SELECT DescriptionAuto__c, Quantity, Subtotal FROM QuoteLineItems ORDER BY CreatedDate DESC) FROM Quote WHERE OpportunityId = :requestData.get('opportunityId') AND Opportunity.AccountId = :requestData.get('accountId')]){
                    Map<String,Object> currentQuote = new Map<String,Object>();

                    currentQuote.put('name',forQuote.Name);
                    currentQuote.put('status',forQuote.Status);
                    currentQuote.put('subtotal',String.valueOf(forQuote.Subtotal.setScale(2)));
                    List<Map<String,Object>> currentQuoteLineItems = new List<Map<String,Object>>();
                    for(QuoteLineItem forQLI : forQuote.QuoteLineItems){
                        currentQuoteLineItems.add(new Map<String,Object>{
                            'description'   =>  forQLI.DescriptionAuto__c,
                            'subtotal'      =>  String.valueOf(forQLI.Subtotal.setScale(2)),
                            'quantity'      =>  String.valueOf(forQLI.Quantity.setScale(2))
                        });
                    }

                    currentQuote.put('quoteLines',currentQuoteLineItems);
                    data.add(currentQuote);
                    returned.put('opportunityName',forQuote.Opportunity.Name);
                }

                returned.put('status','200');
                returned.put('data', data);

            } else {
                returned.put('status','400');
                returned.put('message','accountId and opportunityId are required');
            }
            return returned;
        }
    }
}