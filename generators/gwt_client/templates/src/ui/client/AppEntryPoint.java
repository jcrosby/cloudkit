package ui.client;

import com.google.gwt.core.client.EntryPoint;
import com.google.gwt.user.client.ui.Button;
import com.google.gwt.user.client.ui.ClickListener;
import com.google.gwt.user.client.ui.Label;
import com.google.gwt.user.client.ui.RootPanel;
import com.google.gwt.user.client.ui.Widget;
import com.kaboomerang.gwt.cloudkit.client.context.ApplicationContext;
import com.kaboomerang.gwt.cloudkit.client.context.air.AirApplicationContext;
import com.kaboomerang.gwt.cloudkit.client.event.ActionHandler;
import ui.client.migration.ApplicationMigration;

public class AppEntryPoint implements EntryPoint {
    private ApplicationContext context;

    public void onModuleLoad() {
        final Button button = new Button("Test");
        final Label label = new Label();

        button.addClickListener(new ClickListener() {
            public void onClick(Widget sender) {
                if (label.getText().equals("")) {
                    label.setText("Your GWT setup works. Replace the EntryPoint code when ready.");
                } else {
                    label.setText("");
                }
            }
        });
        
        // Load the ApplicationContext. This provides online/offline detection,
        // auto-updates for desktop client apps, synchronization of database schema versions,
        // and records (under development) automatically.
        context = AirApplicationContext.instance(
                "http://localhost:3000/",        // network status URL, to determine web service connectivity
                "http://localhost:3000/version", // app version check URL, to detect new desktop versions
                "http://localhost:3000/air/",    // base URL for downloading new desktop versions
                new ApplicationMigration(),      // contains all schema migrations and runs only those necessary to be current
                new ActionHandler() {            // called when the context has been through the app update, schema update, record sync cycle once

            public void onSuccess() {
                RootPanel.get().add(button);
                RootPanel.get().add(label);
            }

            public void onError(String error) {
                RootPanel.get().add(new Label("Your GWT setup failed with this error: " + error));
            }
        });
    }
}

