package diametric;

import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import org.jruby.Ruby;
import org.jruby.RubyArray;
import org.jruby.RubyClass;
import org.jruby.RubyHash;
import org.jruby.RubyNil;
import org.jruby.RubyObject;
import org.jruby.anno.JRubyClass;
import org.jruby.anno.JRubyMethod;
import org.jruby.javasupport.JavaUtil;
import org.jruby.runtime.ThreadContext;
import org.jruby.runtime.builtin.IRubyObject;

import datomic.Connection;
import datomic.Database;
import datomic.ListenableFuture;

@JRubyClass(name = "Diametric::Persistence::Connection")
public class DiametricConnection extends RubyObject {
    private static final long serialVersionUID = 3806301567154638371L;
    private Connection conn = null;

    public DiametricConnection(Ruby runtime, RubyClass klazz) {
        super(runtime, klazz);
    }
    
    void init(Connection conn) {
        this.conn = conn;
    }
    
    Connection toJava() {
        return conn;
    }

    @JRubyMethod
    public IRubyObject to_java(ThreadContext context) {
        return JavaUtil.convertJavaToUsableRubyObject(context.getRuntime(), conn);
    }
    
    @JRubyMethod
    public IRubyObject db(ThreadContext context) {
        Database database = conn.db();
        RubyClass clazz = (RubyClass)context.getRuntime().getClassFromPath("Diametric::Persistence::Database");
        DiametricDatabase diametric_database = (DiametricDatabase)clazz.allocate();
        diametric_database.init(database);
        return diametric_database;
    }
    
    @JRubyMethod
    public IRubyObject transact(ThreadContext context, IRubyObject arg) {
        if (!(arg instanceof RubyArray)) return context.getRuntime().getNil();
        System.out.println("TX_DATA: " + arg.toString());
        RubyArray ruby_tx_data = (RubyArray)arg;
        List java_tx_data = new ArrayList();
        for (int i=0; i<ruby_tx_data.getLength(); i++) {
            IRubyObject element = (IRubyObject) ruby_tx_data.get(i);
            if (!(element instanceof RubyHash)) continue;
            RubyHash ruby_hash = (RubyHash)element;
            Map keyvals = new HashMap();
            while(true) {
                IRubyObject pair = ruby_hash.shift(context);
                if (pair instanceof RubyNil) break;
                Object key = DiametricUtils.convertRubyToJava(context, ((RubyArray)pair).shift(context));
                Object value = DiametricUtils.convertRubyToJava(context, ((RubyArray)pair).shift(context));
                keyvals.put(key, value);
            }
            /*
            // debugging
            System.out.print("KEYVALS: ");
            Set ks = keyvals.keySet();
            for (Object k : ks) {
                System.out.print(k +": " + keyvals.get(k) + ", ");
            }
            */
            java_tx_data.add(Collections.unmodifiableMap(keyvals));
        }
        ListenableFuture<java.util.Map> future;
        try {
            future = conn.transact(java_tx_data);
            RubyClass clazz = (RubyClass)context.getRuntime().getClassFromPath("Diametric::Persistence::ListenableFuture");
            DiametricListenableFuture diametric_listenable = (DiametricListenableFuture)clazz.allocate();
            diametric_listenable.init(future);
            return diametric_listenable;
        } catch (Exception e) {
            context.getRuntime().newRuntimeError(e.getMessage());
        }
        return context.getRuntime().getNil();
    }
}
